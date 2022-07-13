<#PSScriptInfo
.VERSION 1.6.0
.GUID 5614d5a5-d33b-4a86-a7bb-ccc91c3f9bb3
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for Kubernetes-related tasks.
#>

'utils.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function New-Namespace([string] $namespace, [Tuple`2[string,string]] $label, [switch] $dryRun) {

	if (-not $dryRun) {
		if (Test-Namespace $namespace) {
			Set-NamespaceLabel $namespace $label.Item1 $label.Item2
			return [string]::Empty
		}
	}

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''

	$newNamespace = kubectl create namespace $namespace -o $output $dryRunParam
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create namespace $namespace, kubectl exited with code $LASTEXITCODE."
	}

	if ($null -eq $label) {
		return $newNamespace
	}

	if (-not $dryRun) {
		Set-NamespaceLabel $namespace $label.Item1 $label.Item2
		return $newNamespace
	}

	# create namespace doesn't currently have a label parameter, so add label to YAML
	$newNamespaceWithLabel = @()
	$newNamespace | ForEach-Object {
		$newNamespaceWithLabel += $_
		if ($_ -eq 'metadata:') {
			$newNamespaceWithLabel += '  labels:'
			$newNamespaceWithLabel += "    $($label.Item1): $($label.Item2)"
		}
	}
	$newNamespaceWithLabel
}

function Test-Namespace([string] $namespace) {

	if ('' -eq $namespace) {
		return $false
	}
	
	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl get namespace $namespace *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function Get-KubectlContext() {

	$contextName = kubectl config current-context
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubectl context, kubectl exited with code $LASTEXITCODE."
	}
	$contextName
}

function Get-KubectlContexts([switch] $nameOnly) {

	$output = @()
	if ($nameOnly) {
		$output = '-o','name'
	}
	$contexts = kubectl config get-contexts @($output)
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubectl contexts, kubectl exited with code $LASTEXITCODE."
	}
	$contexts
}

function Get-KubernetesPort() {

	$info = kubectl cluster-info
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubectl cluster info, kubectl exited with code $LASTEXITCODE."
	}

	$urlMatch = $info[0] | select-string '(?<url>http[A-Z0-9a-z:/\.\-]+)'
	if (-not $urlMatch.Matches.Success) {
		throw "Expected to find URL on line 1: $($info[0])."
	}
	$url = $urlMatch.Matches.Groups[1].Value
	([Uri]$url).Port
}

function Get-KubernetesEndpointsPort() {

	$json = kubectl get endpoints/kubernetes -o json | convertfrom-json
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubernetes endpoints, kubectl exited with code $LASTEXITCODE."
	}

	$port = $null
	$portInfo = $json.subsets.ports | select-object -First 1
	if ($null -ne $portInfo) {
		$port = $portInfo | select-object -ExpandProperty port
	}
	$port
}

function Set-KubectlContext([string] $contextName) {

	$Local:ErrorActionPreference = 'Continue'
	kubectl config use-context $contextName *>&1 | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change kubectl context, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-CurrentKubeContext() {

	# Test-CurrentKubeContext will return false if the caller has no current context (e.g., kubectl config unset current-context)
	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl config current-context *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function Test-ClusterInfo([string] $profileName) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl cluster-info *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function New-Certificate([string] $csrSignerName, [string] $caCertPath, [string] $resourceName, [string] $dnsName, [string] $certPublicKeyFile, [string] $certPrivateKeyFile, [string] $namespace, [string[]] $alternativeNames){

	$altNames = @()
	$altNames = $altNames + "$dnsName.$namespace" + "$dnsName.$namespace.svc.cluster.local" + $alternativeNames

	New-Csr $dnsName `
		$altNames `
		"$dnsName.conf" `
		"$dnsName.csr" `
		$certPrivateKeyFile

	$attempt = 0
	while ($true) {
		try {
			$attempt++

			New-CsrResource $csrSignerName $resourceName "$dnsName.csr" "$dnsName.csrr" $namespace
			New-CsrApproval $resourceName
	
			$certText = Get-Certificate $resourceName
			$caCertText = [io.file]::ReadAllText($caCertPath)
			"$certText`n$caCertText" | out-file $certPublicKeyFile -Encoding ascii -Force

			break
		} catch {

			if ($attempt -gt 3) {
				throw $_
			}
			Write-Verbose "Error: $_`n`nRetrying certificate request..."
			Start-Sleep 60s
		}
	}
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

	# Note: When using EKS, this requires k8s v1.16 or newer. Older EKS releases do not support subject alternative names.
	openssl req -new -config $requestFile -out $csrFile -keyout $keyFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create CSR, openssl exited with code $LASTEXITCODE."
	}
}

function Test-Deployment([string] $namespace, [string] $deploymentName) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get deployment $deploymentName *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Test-NonNamespacedResource([string] $kind, [string] $resourceName) {
	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl get $kind $resourceName *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Test-NamespacedResource([string] $namespace, [string] $kind, [string] $resourceName) {
	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get $kind $resourceName *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Test-StatefulSet([string] $namespace, [string] $statefulSetName) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get statefulset $statefulSetName *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Test-CsrResource([string] $resourceName) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl get csr $resourceName *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Remove-CsrResource([string] $resourceName) {

	kubectl delete csr $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete CSR, kubectl exited with code $LASTEXITCODE."
	}
}

function Get-CsrSignerNameLegacyUnknown {
	'kubernetes.io/legacy-unknown'
}

function New-CsrResource([string] $csrSignerName, [string] $resourceName, [string] $csrFile, [string] $csrResourceFile) {

	$csrSignerNameLegacyUnknown = Get-CsrSignerNameLegacyUnknown
	$isBetaCsrRequired = $csrSignerName -eq $csrSignerNameLegacyUnknown

	$apiVersion = 'certificates.k8s.io/v1'
	if ($isBetaCsrRequired) {

		if (-not (Test-CertificateSigningRequestV1Beta1)) {
			throw "CSR signerName $csrSignerName is invalid because $csrSignerNameLegacyUnknown requires the CSR API version v1beta1"
		}

		$apiVersion = 'certificates.k8s.io/v1beta1'
	}

	if (Test-CsrResource $resourceName) {
		Remove-CsrResource $resourceName
	}


	$resourceRequest = @'
apiVersion: {0}
kind: CertificateSigningRequest
metadata:
  name: {1}
spec:
  groups:
  - system:authenticated
  request: {2}
  signerName: {3}
  usages:
  - digital signature
  - key encipherment
  - server auth
'@ -f $apiVersion, $resourceName, (Convert-Base64 $csrFile), $csrSignerName

	$resourceRequest | out-file  $csrResourceFile -Encoding ascii -Force

	kubectl create -f $csrResourceFile
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

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get svc $name *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function Test-Secret([string] $namespace, [string] $name) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get secret $name *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function Get-SecretFieldValue([string] $namespace, [string] $name, [string] $field) {

	if (-not (Test-Secret $namespace $name)) {
		return $null
	}
	$val = kubectl -n $namespace get secret $name -o jsonpath="{.data.$field}"
	if ($null -eq $val) {
		return $null
	}
	[text.encoding]::ASCII.GetString([convert]::FromBase64String($val))
}

function Remove-Secret([string] $namespace, [string] $name) {

	$Local:ErrorActionPreference = 'Continue'
	kubectl -n $namespace delete secret $name *>&1 | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-GenericSecret([string] $namespace, [string] $name, [hashtable] $keyValues = @{}, [hashtable] $fileKeyValues = @{}, [switch] $dryRun) {
	
	if (-not $dryRun) {
		if (Test-Secret $namespace $name) {
			Remove-Secret $namespace $name
		}
	}

	$pairs = @()
	$tmpPaths = @()
	try {
		$keyValues.Keys | ForEach-Object {

			# apply escape required when running from pwsh
			$value = $keyValues[$_]
			$value = $value -replace '"','\"'

			$pairs += "--from-literal=$_=$value"
		}
		$fileKeyValues.Keys | ForEach-Object {
			$fromFilePath = Set-KubectlFromFilePath $fileKeyValues[$_] ([ref]$tmpPaths)
			$pairs += "--from-file=$_=$fromFilePath"
		}
		if ($pairs.Length -eq 0) {
			throw "Unable to create secret named $name with no data."
		}

		$output = $dryRun ? 'yaml' : 'name'
		$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''
		kubectl -n $namespace create secret generic $name $pairs -o $output $dryRunParam
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to create secret named $name, kubectl exited with code $LASTEXITCODE."
		}
	} finally {
		$tmpPaths | ForEach-Object { Write-Verbose "Removing temporary file '$_'"; Remove-Item $_ -Force }
	}
}

function New-CertificateSecret([string] $namespace, [string] $name, [string] $certFile, [string] $keyFile, [switch] $dryRun) {

	if (-not $dryRun) {
		if (Test-Secret $namespace $name) {
			Remove-Secret $namespace $name
		}
	}

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''

	kubectl -n $namespace create secret tls $name --cert`=$certFile --key`=$keyFile -o $output $dryRunParam
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-ConfigMap([string] $namespace, [string] $name) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get configmap $name *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function Remove-ConfigMap([string] $namespace, [string] $name) {

	$Local:ErrorActionPreference = 'Continue'
	kubectl -n $namespace delete configmap $name *>&1 | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete configmap named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-CertificateConfigMap([string] $namespace, [string] $name, [string] $certFile, [string] $certFilenameInConfigMap, [switch] $dryRun) {
	if ('' -eq $certFilenameInConfigMap) {
		$certFilenameInConfigMap = split-path $certFile -Leaf
	}
	New-ConfigMap $namespace $name @{} @{$certFilenameInConfigMap = $certFile} -dryRun:$dryRun
}

function Set-KubectlFromFilePath([string] $fromFilePath, [ref] $tmpPaths) {
	if ($fromFilePath.Contains(',')) {
		$newFromFilePath = New-TemporaryFile
		$tmpPaths.Value += $newFromFilePath.FullName

		Write-Verbose "Created file '$($newFromFilePath.FullName)' for file '$fromFilePath'"
		Copy-Item -LiteralPath $fromFilePath -Destination $newFromFilePath.FullName

		$fromFilePath = $newFromFilePath.FullName
	}
	$fromFilePath
}

function New-ConfigMap([string] $namespace, [string] $name, [hashtable] $keyValues = @{}, [hashtable] $fileKeyValues = @{}, [switch] $dryRun) {
	
	if (-not $dryRun) {
		if (Test-ConfigMap $namespace $name) {
			Remove-ConfigMap $namespace $name
		}
	}

	$pairs = @()
	$tmpPaths = @()
	try {
		$keyValues.Keys | ForEach-Object {

			# apply escape required when running from pwsh
			$value = $keyValues[$_]
			$value = $value -replace '"','\"'

			$pairs += "--from-literal=$_=$value"
		}
		$fileKeyValues.Keys | ForEach-Object {
			$fromFilePath = Set-KubectlFromFilePath $fileKeyValues[$_] ([ref]$tmpPaths)
			$pairs += "--from-file=$_=$fromFilePath"
		}
		if ($pairs.Length -eq 0) {
			throw "Unable to create configmap named $name with no data."
		}

		$output = $dryRun ? 'yaml' : 'name'
		$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''
		kubectl -n $namespace create configmap $name $pairs -o $output $dryRunParam
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to create configmap named $name, kubectl exited with code $LASTEXITCODE."
		}
	} finally {
		$tmpPaths | ForEach-Object { Write-Verbose "Removing temporary file '$_'"; Remove-Item $_ -Force }
	}
}


function Set-NonNamespacedResource([string] $jsonPath, [string] $kind, [switch] $dryRun) {

	$resourceName = (get-content $jsonPath | ConvertFrom-Json).metadata.name
	if (-not $dryRun -and (Test-NonNamespacedResource $kind $resourceName)) {
		kubectl replace -f $jsonPath -o 'name' # Do not use apply here because it may fail with a resourceVersion mismatch
		return
	}

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''
	kubectl apply -f $jsonPath -o $output $dryRunParam
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create non namespaced resource from $jsonPath, kubectl exited with code $LASTEXITCODE."
	}
}

function Set-K8sResource([string] $path) {

	$Local:ErrorActionPreference = 'Continue'
	kubectl apply -f $path *>&1 | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to apply resource from $path, kubectl exited with code $LASTEXITCODE."
	}
}

function New-NamespacedResource([string] $namespace, [string] $kind, [string] $resourceName, [string] $yamlPath) {

	if (Test-NamespacedResource $namespace $kind $resourceName) {
		Remove-NamespacedResource $namespace $kind $resourceName
	}

	kubectl -n $namespace apply -f $yamlPath -o 'name'
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create $kind resource from $yamlPath, kubectl exited with code $LASTEXITCODE."
	}
}

function New-ImagePullSecret([string] $namespace, 
	[string] $name, 
	[string] $dockerRegistry,
	[string] $dockerRegistryUser,
	[string] $dockerRegistryPwd,
	[switch] $dryRun) {

	if (-not $dryRun) {
		if (Test-Secret $namespace $name) {
			Remove-Secret $namespace $name
		}
	}

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''

	kubectl -n $namespace create secret docker-registry $name --docker-server=$dockerRegistry --docker-username=$dockerRegistryUser --docker-password=$dockerRegistryPwd -o $output $dryRunParam
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

function Wait-RunningPod([string] $message, [int] $waitSeconds, [string] $namespace, [string] $podName) {

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		$result = kubectl -n $namespace get pod --field-selector=status.phase=Running,metadata.name="$podName"
		
		if ($null -ne $result) {
			Write-Verbose "Wait is over with $($timeoutTime.Subtract([datetime]::Now).TotalSeconds) second(s) remaining before timeout"
			break
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because a timeout occurred while waiting for pod $podName to be in a ready status."
		}
		Write-Verbose "Pod $podName is not yet running. Another check will occur in $sleepSeconds seconds ($message)."
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
	$startTime = [datetime]::Now
	$timeoutTime = $startTime.AddSeconds($waitSeconds)
	while ($true) {

		$resourceExists = ($resourceType -eq 'deployment' -and (Test-Deployment $namespace $resourceName)) -or 
			($resourceType -eq 'statefulset' -and (Test-StatefulSet $namespace $resourceName))

		if ($resourceExists) {

			Write-Verbose "Fetching status of $resourceType named $resourceName in namespace $namespace..."
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

		kubectl -n $namespace get pod
		
		$now = [datetime]::Now
		Write-Verbose $message
		Write-Verbose "  Current replica count does not yet match desired count."
		Write-Verbose "    Elapsed time is $($now.Subtract($startTime).TotalSeconds) seconds."
		Write-Verbose "    Wait will timeout in $($timeoutTime.Subtract($now).TotalSeconds) seconds."
		Write-Verbose "    Another replica count check will occur in $sleepSeconds seconds."
		start-sleep -seconds $sleepSeconds
	}
}

function Test-Pod([string] $namespace, [string] $podName) {

	$local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get "pod/$podName" *>&1 | Out-Null
	0 -eq $LASTEXITCODE
}

function Remove-Pod([string] $namespace, [string] $podName, [switch] $force) {

	if (-not (Test-Pod $namespace $podName)) {
		return
	}

	kubectl -n $namespace delete "pod/$podName" ($force ? '--force' : '') ($force ? '--grace-period=0' : '') ($force ? '--wait=false' : '')
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete pod/$podName in namespace $namespace, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-PriorityClass([string] $name) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl get priorityclass $name *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Remove-PriorityClass([string] $name) {

	$Local:ErrorActionPreference = 'Continue'
	kubectl delete priorityclass $name *>&1 | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete priority class named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-PriorityClass([string] $name, [int] $value, [switch] $dryRun) {

	if (-not $dryRun) {
		if (Test-PriorityClass $name) {
			Remove-PriorityClass $name
		}
	}

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''
	kubectl create priorityclass $name --value=$value -o $output $dryRunParam
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
	if ($resourceSpec -match '\s*resources:$') { $resourceSpec += ' {}' }

	$resourceSpec
}

function Format-NodeSelector([Tuple`2[string,string][]] $keyValues) {

	if ($null -eq $keyValues) {
		return '{}'
	}

	$items = @{}
	$keyValues | ForEach-Object {
		$items[$_.item1] = $_.item2
	}
	ConvertTo-YamlMap $items
}

function Format-PodTolerationNoScheduleNoExecute([Tuple`2[string,string][]] $keyValues) {

	if ($null -eq $keyValues) {
		return '[]'
	}
	
	$items = @()
	$keyValues | ForEach-Object {

		$toleration = @{}
		$toleration['key'] = $_.item1
		$toleration['value'] = $_.item2
		$toleration['operator'] = 'Equal'
		$toleration['effect'] = 'NoSchedule'
		$items += ConvertTo-YamlMap $toleration

		$toleration['effect'] = 'NoExecute'
		$items += ConvertTo-YamlMap $toleration
	}

	if ($items.count -eq 0) {
		return '[]'
	}
	'[' + "{0}" -f ([string]::Join(',', $items)) + ']'
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

function Get-ServiceAccountName([string] $namespace,
	[string] $resourceType,
	[string] $resourceName) {

	$name = kubectl -n $namespace get $resourceType $resourceName -o jsonpath='{.spec.template.spec.serviceAccountName}'
	if (0 -ne $LASTEXITCODE) {
		throw "Unable to set replicas for $resourceType named $resourceName, kubectl exited with code $LASTEXITCODE."
	}
	$name
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

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl -n $namespace get job $resourceName *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Remove-KubernetesJob([string] $namespace,
	[string] $resourceName) {
	
	kubectl delete -n $namespace job $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete job, kubectl exited with code $LASTEXITCODE."
	}
}

function Remove-KubernetesPvc([string] $namespace,
	[string] $resourceName) {
	
	kubectl delete -n $namespace pvc $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete pvc, kubectl exited with code $LASTEXITCODE."
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

function Remove-NamespacedResource([string] $namespace, [string] $kind, [string] $resourceName) {

	kubectl -n $namespace delete $kind $resourceName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete $resourceName of kind $kind, kubectl exited with code $LASTEXITCODE."
	}
}

function Copy-K8sItem([string] $namespace, 
	[string] $sourcePath,
	[string] $podName,
	[string] $containerName,
	[string] $destinationPath) {

	kubectl -n $namespace cp   -c $containerName $sourcePath $podName`:$destinationPath
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to copy to pod, kubectl exited with exit code $LASTEXITCODE."
	}
}

function Test-KubectlUsesDryRunBool { 
	$null -ne (kubectl create --help | select-string '--dry-run=false' -SimpleMatch) 
}

function Get-KubectlDryRunParam {
	(Test-KubectlUsesDryRunBool) ? '--dry-run=true' : '--dry-run=client'
}

function Test-ResourceApiVersion([string] $resource, [string] $apiVersion) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	kubectl explain $resource --api-version $apiVersion *>&1 | out-null
	0 -eq $LASTEXITCODE
}

function Test-CertificateSigningRequestV1Beta1 {

	Test-ResourceApiVersion 'CertificateSigningRequest' 'certificates.k8s.io/v1beta1'
}

function Test-CertificateSigningRequestV1Beta1 {

	Test-ResourceApiVersion 'CustomResourceDefinition' 'apiextensions.k8s.io/v1beta1'
}

function Test-DeploymentLabel([string] $namespace, [string] $labelName, [string] $labelValue) {

	if (-not (Test-Namespace($namespace))) {
		return $false
	}

	$Local:ErrorActionPreference = 'SilentlyContinue'
	$deployments = kubectl -n $namespace get deployment -l "$labelName=$labelValue" -o json | convertfrom-json
	$deployments.items.length -ne 0
}