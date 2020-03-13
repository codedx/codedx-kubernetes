. (join-path $PSScriptRoot 'utils.ps1')

function New-Namespace([string] $namespace) {

	kubectl create namespace $namespace
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create namespace $namespace, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-Namespace([string] $namespace) {

	kubectl get namespace $namespace | out-null
	0 -eq $LASTEXITCODE
}

function Set-KubectlContext([string] $profileName) {

	kubectl config use-context $profileName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change kubectl context, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-ClusterInfo([string] $profileName) {

	kubectl cluster-info | out-null
	0 -eq $LASTEXITCODE
}

function New-Certificate([string] $caCertPath, [string] $resourceName, [string] $dnsName, [string] $namespace, [string[]] $alternativeNames){

	$altNames = @()
	$altNames = $altNames + $dnsName + "$dnsName.$namespace" + $alternativeNames

	New-Csr "$dnsName.$namespace.svc.cluster.local" `
		$altNames `
		"$dnsName.conf" `
		"$dnsName.csr" `
		"$dnsName.key"

	New-CsrResource $resourceName "$dnsName.csr" "$dnsName.csrr"
	New-CsrApproval $resourceName

	$certText = Get-Certificate $resourceName
	$caCertText = [io.file]::ReadAllText($caCertPath)
	"$certText`n$caCertText" | out-file "$resourceName.pem" -Encoding ascii -Force
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

	openssl req -new -config $requestFile -out $csrFile -keyout $keyFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create CSR, openssl exited with code $LASTEXITCODE."
	}
}

function Test-Deployment([string] $namespace, [string] $deploymentName) {
	kubectl -n $namespace get deployment $deploymentName | out-null
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

function New-ImagePullSecret([string] $namespace, [string] $name, [string] $dockerConfigJson) {

	if (Test-Secret $namespace $name) {
		Remove-Secret $namespace $name
	}

	$imagePullSecret = @'
apiVersion: v1
metadata:
  name: {0}
data:
  .dockerconfigjson: {1}
kind: Secret
type: kubernetes.io/dockerconfigjson  
'@ -f $name, $dockerConfigJson

	$imagePullSecret | out-file "$name.yaml" -Encoding ascii -Force
	kubectl -n $namespace create -f "$name.yaml"
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
			$results = kubectl get pod --field-selector=status.phase!=Running --all-namespaces
		} else {
			$results = kubectl get pod --field-selector=status.phase!=Running -n $namespace
		}
		
		if ($null -eq $results) {
			Write-Verbose "Wait is over with $($timeoutTime.Subtract([datetime]::Now).TotalSeconds) second(s) remaining before timeout"
			Write-Verbose 'All pods show a Running status'
			break
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because a timeout occurred while waiting for all pods to be in a Running state ($message)."
		}
		Write-Verbose "Some pods are not running. Another check will occur in $sleepSeconds seconds ($message)."
		start-sleep -seconds $sleepSeconds
	}
}

function Wait-Deployment([string] $message, [int] $waitSeconds, [string] $namespace, [string] $deploymentName, [string] $totalReplicas) {

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		if (Test-Deployment $namespace $deploymentName) {

			Write-Verbose "Fetching status of deployment named $deploymentName..."
			$deploymentJson = kubectl -n $namespace get deployment $deploymentName -o json
			if ($LASTEXITCODE -ne 0) {
				throw "Unable to wait for deployment, kubectl exited with code $LASTEXITCODE."
			}

			$readyReplicas = ($deploymentJson | convertfrom-json).status.readyReplicas
			if ($null -eq $readyReplicas) {
				$readyReplicas = 0
			}
			
			Write-Verbose "Found $readyReplicas of $totalReplicas ready"
			if ($totalReplicas -eq $readyReplicas) {
				Write-Verbose "Wait is over with $($timeoutTime.Subtract([datetime]::Now).TotalSeconds) second(s) remaining before timeout"
				break
			}

		} else {
			Write-Verbose "Deployment $deploymentName in namespace $namespace does not exist"
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because the deployment $deploymentName is not ready ($message)"
		}

		Write-Verbose "Some replicas are not ready. Another check will occur in $sleepSeconds seconds ($message)."
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

function Format-ResourceLimitRequest([string] $requestMemory, [string] $requestCpu, [string] $limitMemory, [string] $limitCpu, [int] $indent) {

	$resources = @'
resources:
  requests:
    memory: {0}
    cpu: {1}
  limits:
    memory: {2}
    cpu: {3}
'@ -f $requestMemory,$requestCpu,$limitMemory,$limitCpu

	$resources = $resources.split("`n") | Where-Object { 
		$_ -notmatch 'memory:\s$' -and $_ -notmatch 'cpu:\s$' 
	} | ForEach-Object { 
		"{0}{1}" -f ([string]::new(' ', $indent)),$_ 
	}

	[string]::join("`n", $resources)
}