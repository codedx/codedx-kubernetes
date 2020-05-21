<#PSScriptInfo
.VERSION 1.0.1
.GUID 5614d5a5-d33b-4a86-a7bb-ccc91c3f9bb3
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for Kubernetes-related tasks.
#>

. (join-path $PSScriptRoot 'utils.ps1')

function New-Namespace([string] $namespace) {

	kubectl create namespace $namespace
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create namespace $namespace, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-Namespace([string] $namespace) {

	if ('' -eq $namespace) {
		return $false
	}
	
	kubectl get namespace $namespace | out-null
	0 -eq $LASTEXITCODE
}

function Get-KubectlContext() {

	$contextName = kubectl config current-context
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubectl context, kubectl exited with code $LASTEXITCODE."
	}
	$contextName
}

function Set-KubectlContext([string] $contextName) {

	kubectl config use-context $contextName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change kubectl context, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-ClusterInfo([string] $profileName) {

	kubectl cluster-info | out-null
	0 -eq $LASTEXITCODE
}

function New-Certificate([string] $caCertPath, [string] $resourceName, [string] $dnsName, [string] $certPublicKeyFile, [string] $certPrivateKeyFile, [string] $namespace, [string[]] $alternativeNames){

	$altNames = @()
	$altNames = $altNames + "$dnsName.$namespace" + "$dnsName.$namespace.svc.cluster.local" + $alternativeNames

	New-Csr $dnsName `
		$altNames `
		"$dnsName.conf" `
		"$dnsName.csr" `
		$certPrivateKeyFile

	New-CsrResource $resourceName "$dnsName.csr" "$dnsName.csrr"
	New-CsrApproval $resourceName

	$certText = Get-Certificate $resourceName
	$caCertText = [io.file]::ReadAllText($caCertPath)
	"$certText`n$caCertText" | out-file $certPublicKeyFile -Encoding ascii -Force
}

function New-Csr([string] $subjectName, [string[]] $subjectAlternativeNames, [string] $requestFile, [string] $csrFile, [string] $keyFile) {

	$request = @'
[ req ]
default_bits = 2048
prompt = no
encrypt_key = no
distinguished_name = req_dn
req_extensions = req_ext

[ req_dn ]
CN = {0}

[ req_ext ]
subjectAltName = @alt_names

[ alt_names ]
DNS.1 = {0}
'@ -f $subjectName

$i = 2
$subjectAlternativeNames | ForEach-Object {
	$request = $request + ("`nDNS.{0} = {1}" -f $i,$_)
	$i += 1
}

	$request | out-file $requestFile -Encoding ascii -Force

	# Note: When using EKS, this requires k8s v1.16 or newer. Older EKS releases do not support subect alternative names.
	openssl req -new -config $requestFile -out $csrFile -keyout $keyFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create CSR, openssl exited with code $LASTEXITCODE."
	}
}

function Test-Deployment([string] $namespace, [string] $deploymentName) {
	kubectl -n $namespace get deployment $deploymentName | out-null
	$LASTEXITCODE -eq 0
}

function Test-StatefulSet([string] $namespace, [string] $statefulSetName) {
	kubectl -n $namespace get statefulset $statefulSetName | out-null
	$LASTEXITCODE -eq 0
}

function Test-CsrResource([string] $resourceName) {

	kubectl get csr $resourceName | out-null
	$LASTEXITCODE -eq 0
}

function Remove-CsrResource([string] $resourceName) {

	kubectl delete csr $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete CSR, kubectl exited with code $LASTEXITCODE."
	}
}

function New-CsrResource([string] $resourceName, [string] $csrFile, [string] $csrResourceFile) {

	if (Test-CsrResource $resourceName) {
		Remove-CsrResource $resourceName
	}

	$resourceRequest = @'
apiVersion: certificates.k8s.io/v1beta1
kind: CertificateSigningRequest
metadata:
  name: {0}
spec:
  groups:
  - system:authenticated
  request: {1}
  usages:
  - digital signature
  - key encipherment
  - server auth
'@ -f $resourceName, (Convert-Base64 $csrFile)

	$resourceRequest | out-file  $csrResourceFile -Encoding ascii -Force

	kubectl apply -f $csrResourceFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to apply CSR resource, kubectl exited with code $LASTEXITCODE."
	}
}

function New-CsrApproval([string] $resourceName) {

	kubectl certificate approve $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to approve CSR, kubectl exited with code $LASTEXITCODE."
	}
}

function Get-Certificate([string] $resourceName, [int] $waitSeconds=120) {

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		$certData = kubectl get csr $resourceName -o jsonpath='{.status.certificate}'
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to retrieve certificate from CSR, kubectl exited with code $LASTEXITCODE."
		}

		if ($null -ne $certData) {

			$certBytes = [convert]::frombase64string($certData)
			[text.encoding]::ascii.getstring($certBytes)
			break
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because the certificate $resourceName is not ready"
		}

		Write-Verbose "Certificate $resourceName is not available. Another check will occur in $sleepSeconds seconds."
		start-sleep -seconds $sleepSeconds
	}
}

function Set-NamespaceLabel([string] $namespace, [string] $labelName, [string] $labelValue) {

	kubectl label namespace $namespace $labelName`=$labelValue --overwrite
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create $namespace label with $labelName=$labelValue, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-Service([string] $namespace, [string] $name) {

	kubectl -n $namespace get svc $name | out-null
	0 -eq $LASTEXITCODE
}

function Test-Secret([string] $namespace, [string] $name) {

	kubectl -n $namespace get secret $name | out-null
	0 -eq $LASTEXITCODE
}

function Remove-Secret([string] $namespace, [string] $name) {

	kubectl -n $namespace delete secret $name | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-CertificateSecret([string] $namespace, [string] $name, [string] $certFile, [string] $keyFile) {

	if (Test-Secret $namespace $name) {
		Remove-Secret $namespace $name
	}

	kubectl -n $namespace create secret generic $name --from-file`=$certFile --from-file`=$keyFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-FileSecret([string] $namespace, [string] $name, [string] $file) {

	if (Test-Secret $namespace $name) {
		Remove-Secret $namespace $name
	}

	kubectl -n $namespace create secret generic $name --from-file`=$file
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-ConfigMap([string] $namespace, [string] $name) {

	kubectl -n $namespace get configmap $name | out-null
	0 -eq $LASTEXITCODE
}

function Remove-ConfigMap([string] $namespace, [string] $name) {

	kubectl -n $namespace delete configmap $name | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete configmap named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-CertificateConfigMap([string] $namespace, [string] $name, [string] $certFile) {

	if (Test-ConfigMap $namespace $name) {
		Remove-ConfigMap $namespace $name
	}

	kubectl -n $namespace create configmap $name --from-file`=$certFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create configmap named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-ImagePullSecret([string] $namespace, `
	[string] $name, `
	[string] $dockerRegistry,
	[string] $dockerRegistryUser,
	[string] $dockerRegistryPwd) {

	if (Test-Secret $namespace $name) {
		Remove-Secret $namespace $name
	}

	kubectl -n $namespace create secret docker-registry $name --docker-server=$dockerRegistry --docker-username=$dockerRegistryUser --docker-password=$dockerRegistryPwd
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create image pull secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function Wait-AllRunningPods([string] $message, [int] $waitSeconds, [string] $namespace) {

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		Write-Verbose "Checking for pods that are not in a Running status ($message)..."

		if ('' -eq $namespace) {
			kubectl get pod --all-namespaces
		} else {
			kubectl get pod -n $namespace
		}
		
		if ('' -eq $namespace) {
			$results = kubectl get pod --field-selector=status.phase!=Running,status.phase!=Succeeded,status.phase!=Failed --all-namespaces
		} else {
			$results = kubectl get pod --field-selector=status.phase!=Running,status.phase!=Succeeded,status.phase!=Failed -n $namespace
		}
		
		if ($null -eq $results) {
			Write-Verbose "Wait is over with $($timeoutTime.Subtract([datetime]::Now).TotalSeconds) second(s) remaining before timeout"
			Write-Verbose 'All pods show a Running status'
			break
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because a timeout occurred while waiting for all pods to be in a ready status. One or more pods have a status other than Running, Succeeded, or Failed. ($message)."
		}
		Write-Verbose "Some pods are not running. Another check will occur in $sleepSeconds seconds ($message)."
		start-sleep -seconds $sleepSeconds
	}
}

function Wait-Deployment([string] $message, [int] $waitSeconds, [string] $namespace, [string] $deploymentName, [string] $totalReplicas) {

	Wait-ReplicasReady $message $waitSeconds $namespace 'deployment' $deploymentName $totalReplicas
}

function Wait-StatefulSet([string] $message, [int] $waitSeconds, [string] $namespace, [string] $statefulSetName, [string] $totalReplicas) {

	Wait-ReplicasReady $message $waitSeconds $namespace 'statefulset' $statefulSetName $totalReplicas
}

function Wait-JobSuccess([string] $message, [int] $waitSeconds, [string] $namespace, [string] $jobName) {

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		$success = kubectl -n $namespace get job $jobName -o jsonpath='{.status.succeeded}'
		if ('1' -eq $success) {
			break
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because the job '$jobName' has not yet succeeded ($message)"
		}

		Write-Verbose "Job has not yet succeeded. Another check will occur in $sleepSeconds seconds ($message)."
		start-sleep -seconds $sleepSeconds
	}
}

function Wait-ReplicasReady([string] $message, [int] $waitSeconds, [string] $namespace, [string] $resourceType, [string] $resourceName, [string] $totalReplicas) {

	if ($resourceType -ne 'deployment' -and $resourceType -ne 'statefulset') {
		throw "Unable to wait for resource type '$resourceType'"
	}

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		$resourceExists = ($resourceType -eq 'deployment' -and (Test-Deployment $namespace $resourceName)) -or 
			($resourceType -eq 'statefulset' -and (Test-StatefulSet $namespace $resourceName))

		if ($resourceExists) {

			Write-Verbose "Fetching status of $resourceType named $resourceName..."
			$readyReplicas = kubectl -n $namespace get $resourceType $resourceName -o jsonpath='{.status.readyReplicas}'
			if ($LASTEXITCODE -ne 0) {
				throw "Unable to wait for $resourceType $resourceName, kubectl exited with code $LASTEXITCODE."
			}

			if ($null -eq $readyReplicas) {
				$readyReplicas = 0
			}
			
			Write-Verbose "Found $readyReplicas of $totalReplicas ready"
			if ($totalReplicas -eq $readyReplicas) {
				Write-Verbose "Wait is over with $($timeoutTime.Subtract([datetime]::Now).TotalSeconds) second(s) remaining before timeout"
				break
			}

		} else {
			Write-Verbose "Resource $resourceName in namespace $namespace does not exist"
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because the $resourceType $resourceName is not ready ($message)"
		}

		Write-Verbose "Current replica count does not yet match desired count. Another check will occur in $sleepSeconds seconds ($message)."
		start-sleep -seconds $sleepSeconds
	}
}

function Test-PriorityClass([string] $name) {

	kubectl get priorityclass $name | out-null
	$LASTEXITCODE -eq 0
}

function New-PriorityClass([string] $name, [int] $value) {

	kubectl create priorityclass $name --value=$value
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create PriorityClass, kubectl exited with code $LASTEXITCODE."
	}
}

function Format-ResourceLimitRequest([string] $requestMemory, [string] $requestCpu, [string] $requestEphemeralStorage,
	[string] $limitMemory, [string] $limitCpu, [string] $limitEphemeralStorage,
	[int] $indent) {

	$resources = @'
resources:
  requests:
    memory: {0}
    cpu: {1}
    ephemeral-storage: {4}
  limits:
    memory: {2}
    cpu: {3}
    ephemeral-storage: {5}
'@ -f $requestMemory.trim(),$requestCpu.trim(),
	$limitMemory.trim(),$limitCpu.trim(),
	$requestEphemeralStorage.trim(),$limitEphemeralStorage.trim()

	$resourcesLines = $resources.split("`n") | Where-Object { 
		$_ -notmatch 'memory:\s$' -and $_ -notmatch 'cpu:\s$' -and $_ -notmatch 'ephemeral\-storage:\s$' 
	} | ForEach-Object { 
		"{0}{1}" -f ([string]::new(' ', $indent)),$_ 
	}

	$resourceSpec = [string]::join("`n", $resourcesLines)

	if ($resourceSpec -match '\s+requests:\n\s+limits:') { $resourceSpec = $resourceSpec -replace '\s+requests:','' }
	if ($resourceSpec -notmatch '\s+limits:\n') { $resourceSpec = $resourceSpec -replace '\s+limits:$','' }
	if ($resourceSpec -match '\s*resources:$') { $resourceSpec = '' }

	$resourceSpec
}

function Set-Replicas([string] $namespace,
	[string] $resourceType,
	[string] $resourceName,
	[int]    $replicaCount,
	[int]    $waitSeconds) {

	kubectl -n $namespace scale --replicas=$replicaCount $resourceType $resourceName
	if (0 -ne $LASTEXITCODE) {
		throw "Unable to set replicas for $resourceType named $resourceName, kubectl exited with code $LASTEXITCODE."
	}

	Wait-ReplicasReady 'Replica Wait' $waitSeconds $namespace $resourceType $resourceName $replicaCount
}

function Set-DeploymentReplicas([string] $namespace,
	[string] $resourceName,
	[int]    $replicaCount,
	[int]    $waitSeconds) {

	Set-Replicas $namespace 'deployment' $resourceName $replicaCount $waitSeconds
}

function Set-StatefulSetReplicas([string] $namespace,
	[string] $resourceName,
	[int]    $replicaCount,
	[int]    $waitSeconds) {

	Set-Replicas $namespace 'statefulset' $resourceName $replicaCount $waitSeconds
}

function Test-KubernetesJob([string] $namespace,
	[string] $resourceName) {

	kubectl -n $namespace get job $resourceName | out-null
	$LASTEXITCODE -eq 0
}

function Remove-KubernetesJob([string] $namespace,
	[string] $resourceName) {
	
	kubectl delete -n $namespace job $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete job, kubectl exited with code $LASTEXITCODE."
	}
}


function Edit-ResourceJsonPath([string] $namespace, [string] $resourceKind, [string] $resourceName, [string] $jsonPatch) {

	kubectl -n $namespace patch $resourceKind $resourceName --type=json -p $jsonPatch
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to edit resource with json patch, kubectl exited with code $LASTEXITCODE."
	}
}

function Edit-ResourceStrategicPatch([string] $namespace, [string] $resourceKind, [string] $resourceName, [string] $patch) {

	kubectl -n $namespace patch $resourceKind $resourceName -p $patch
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to edit resource with strategic patch, kubectl exited with code $LASTEXITCODE."
	}
}

function Add-ResourceLabel([string] $namespace, [string] $resourceKindAndName, [string] $labelKey, [string] $labelValue) {

	if ($namespace -eq '') {
		kubectl label $resourceKindAndName "$labelKey=$labelValue" --overwrite
	} else {
		kubectl -n $namespace label $resourceKindAndName "$labelKey=$labelValue" --overwrite
	}
	
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add label to resource, kubectl exited with code $LASTEXITCODE."
	}
}

function Remove-ResourceLabel([string] $namespace, [string] $resourceKindAndName, [string] $labelKey) {

	if ($namespace -eq '') {
		kubectl label $resourceKindAndName "$labelKey-"
	} else {
		kubectl -n $namespace label $resourceKindAndName "$labelKey-"
	}
	
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to remove label from resource, kubectl exited with code $LASTEXITCODE."
	}
}
