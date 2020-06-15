<#PSScriptInfo
.VERSION 1.0.2
.GUID 170f536d-9be8-42fc-8bec-67e8c22e2fb2
.AUTHOR Code Dx
#>

<#
.DESCRIPTION
This script uses Helm to install and configure Code Dx and Tool Orchestration on a minikube cluster.

The following tools must be installed and included in your PATH prior to running this script:

1 minikube
2 helm tool (v3)
3 kubectl
4 openssl
5 git
6 keytool

7 socat (when using $vmDriver 'none')
#>

param (
	[string]   $clusterCertificateAuthorityCertPath="$HOME/.minikube/ca.crt",
	[string]   $codeDxDnsName = (hostname).tolower(),
	[int]      $waitTimeSeconds = 600,

	[int]      $dbVolumeSizeGiB = 32,
	[int]      $dbSlaveReplicaCount = 1,
	[int]      $dbSlaveVolumeSizeGiB = 32,
	[int]      $minioVolumeSizeGiB = 32,
	[int]      $codeDxVolumeSizeGiB = 32,

	[int]      $toolServiceReplicas = 3,

	[bool]     $useTLS  = $true,
	[bool]     $usePSPs = $true,

	[bool]     $skipNetworkPolicies = $true,

	[string]   $namespaceToolOrchestration = 'cdx-svc',
	[string]   $namespaceCodeDx = 'cdx-app',
	[string]   $releaseNameCodeDx = 'codedx-app',
	[string]   $releaseNameToolOrchestration = 'codedx-tool-orchestration',

	[int]      $kubeApiTargetPort = 8443,

	[string]   $k8sVersion = 'v1.14.6',
	[string]   $minikubeProfile = 'minikube-1-14-6',
	[int]      $nodeCPUs = 4,
	[string]   $nodeMemory = '16g',
	[string]   $vmDriver = 'virtualbox',

	[switch]   $letsEncryptCertManagerInstall,
	[switch]   $skipToolOrchestration
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'../core/common/helm.ps1','../core/common/codedx.ps1','../core/common/minikube.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

if (-not (Test-IsCore)) {
	write-error 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
}

$isElevated = Test-IsElevated

if ($IsWindows) {
	if (-not $isElevated) {
			write-error "Unable to continue because you must run this script elevated"
	}
} else {
	if ($vmDriver -eq 'none') {
			if (-not $isElevated) {
					write-error "Unable to continue because you must run this script as the root user"
			}
	} else {
			if ($isElevated) {
					write-error "Unable to continue because you cannot run this script as the root user"
			}
	}
}

if ($null -eq (Get-AppCommandPath 'minikube')) {
	write-error "Unable to continue because minikube cannot be found. Is minikube installed and included in your PATH?"
}

$workDir = "$HOME/.codedx-$minikubeProfile"
$varsPath = Join-Path $workDir 'vars.csv'
$codeDxPortNumber = 8443

$createCluster = -not (Test-MinikubeProfile $minikubeProfile $vmDriver $k8sVersion)
if ($createCluster) {

	$extraConfig = @()
	if ($vmDriver -eq 'none') {
		$extraConfig = '--extra-config=kubeadm.ignore-preflight-errors=SystemVerification','--extra-config=kubelet.resolv-conf=/run/systemd/resolve/resolv.conf'
	}

	Write-Verbose "Determining disk size requirement..."
	$minikubeDiskSizeGiB = 20
	$nodeDiskSize = [string]($dbVolumeSizeGiB + $dbSlaveReplicaCount * $dbSlaveVolumeSizeGiB + $minioVolumeSizeGiB + $codeDxVolumeSizeGiB + $minikubeDiskSizeGiB) + 'g'

	Write-Verbose "Profile does not exist. Creating new minikube profile named $minikubeProfile for k8s version $k8sVersion..."
	New-MinikubeCluster $minikubeProfile $k8sVersion $vmDriver $nodeCPUs $nodeMemory $nodeDiskSize $extraConfig

	if ($vmDriver -eq 'none') {
		New-ReadWriteOncePersistentVolume $minioVolumeSizeGiB
		New-ReadWriteOncePersistentVolume $codeDxVolumeSizeGiB
		New-ReadWriteOncePersistentVolume $dbVolumeSizeGiB
		for ($i = 0; $i -lt $dbSlaveReplicaCount; $i++) {
			New-ReadWriteOncePersistentVolume $dbSlaveVolumeSizeGiB
		}
	}

	$useNetworkPolicies = -not $skipNetworkPolicies
	if ($useNetworkPolicies) {
		Write-Verbose "Adding network policy provider..."
		Add-CalicoNetworkPolicyProvider $waitTimeSeconds
	}

	Write-Verbose 'Stopping minikube cluster...'
	Stop-MinikubeCluster $minikubeProfile

	Write-Verbose 'Starting minikube cluster...'
	Start-MinikubeCluster $minikubeProfile $k8sVersion $vmDriver $waitTimeSeconds -useNetworkPolicy:$useNetworkPolicies $extraConfig

	Write-Verbose 'Waiting for running pods...'
	Wait-AllRunningPods 'Cluster Ready' $waitTimeSeconds

	$provisionIngressController = { Add-IngressAddon $minikubeProfile $waitTimeSeconds }

	& (join-path $PSScriptRoot '../setup.ps1') `
		-workDir $workDir `
		-clusterCertificateAuthorityCertPath $clusterCertificateAuthorityCertPath `
		-codeDxDnsName $codeDxDnsName `
		-waitTimeSeconds $waitTimeSeconds `
		-dbVolumeSizeGiB $dbVolumeSizeGiB `
		-dbSlaveReplicaCount $dbSlaveReplicaCount `
		-dbSlaveVolumeSizeGiB $dbSlaveVolumeSizeGiB `
		-minioVolumeSizeGiB $minioVolumeSizeGiB `
		-codeDxVolumeSizeGiB $codeDxVolumeSizeGiB `
		-toolServiceReplicas $toolServiceReplicas `
		-useTLS $useTLS `
		-usePSPs $usePSPs `
		-skipNetworkPolicies $skipNetworkPolicies `
		-namespaceToolOrchestration $namespaceToolOrchestration `
		-namespaceCodeDx $namespaceCodeDx `
		-releaseNameCodeDx $releaseNameCodeDx `
		-releaseNameToolOrchestration $releaseNameToolOrchestration `
		-kubeApiTargetPort $kubeApiTargetPort `
		-nginxIngressControllerInstall $false `
		-letsEncryptCertManagerInstall $letsEncryptCertManagerInstall `
		-provisionIngressController $provisionIngressController `
		-skipToolOrchestration:$skipToolOrchestration `
		@args

	Write-Verbose 'Shutting down cluster...'
	Stop-MinikubeCluster $minikubeProfile

	Write-Verbose 'Saving configuration for startup process...'
	$vars = @{
		'codeDxDnsName' = $codeDxDnsName;
		'codeDxPortNumber' = $codeDxPortNumber;
		'namespaceCodeDx' = $namespaceCodeDx;
		'namespaceToolOrchestration' = $namespaceToolOrchestration;
		'releaseNameCodeDx' = $releaseNameCodeDx;
		'releaseNameToolOrchestration' = $releaseNameToolOrchestration;
		'skipToolOrchestration' = $skipToolOrchestration;
		'toolServiceReplicas' = $toolServiceReplicas;
		'useNetworkPolicies' = $useNetworkPolicies;
		'usePSPs' = $usePSPs;
		'useTLS' = $useTLS;
		'vmDriver' = $vmDriver;
		'waitTimeSeconds' = $waitTimeSeconds;
		'workDir' = $workDir
	}
	New-Object psobject -Property $vars | Export-Csv -LiteralPath $varsPath -Encoding ascii
}

if (-not (Test-Path $varsPath)) {
	Write-Host "A previous attempt to create a cluster failed. Delete that cluster before continuing by running this command:`nminikube -p $minikubeProfile delete"
	Exit 1
}

Write-Verbose 'Reading saved startup configuration...'
$vars = Import-Csv -LiteralPath $varsPath
$vars.useNetworkPolicies = [convert]::ToBoolean($vars.useNetworkPolicies)
$vars.usePSPs = [convert]::ToBoolean($vars.usePSPs)
$vars.useTLS = [convert]::ToBoolean($vars.useTLS)
$vars.skipToolOrchestration = [convert]::ToBoolean($vars.skipToolOrchestration)

$extraConfig = @()
if ($vars.vmDriver -eq 'none') {
	$extraConfig = '--extra-config=kubeadm.ignore-preflight-errors=SystemVerification','--extra-config=kubelet.resolv-conf=/run/systemd/resolve/resolv.conf'
}

Write-Output "Using saved configuration:`n$vars"

Write-Verbose "Testing minikube status for profile $minikubeProfile..."
if (Test-MinikubeStatus $minikubeProfile) {
	Write-Verbose "Stopping minikube for profile $minikubeProfile..."
	Stop-MinikubeCluster $minikubeProfile
}

Write-Verbose "Starting minikube cluster for profile $minikubeProfile with k8s version $k8sVersion..."
Start-MinikubeCluster $minikubeProfile $k8sVersion $vmDriver $vars.waitTimeSeconds -useNetworkPolicy:$($vars.useNetworkPolicies) -usePSP:$($vars.usePSPs) $extraConfig

Write-Verbose "Setting kubectl context to minikube profile $minikubeProfile..."
Set-KubectlContext $minikubeProfile

Write-Verbose 'Checking cluster status...'
if (-not (Test-ClusterInfo)) {
	throw "Unable to continue because k8s cluster is not running"
}

Write-Verbose 'Waiting to check deployment status...'
Start-Sleep -Seconds 60

if (-not $vars.skipToolOrchestration) {
	Write-Verbose 'Waiting for Tool Orchestration deployment...'
	Wait-Deployment 'Tool Orchestration Deployment' $vars.waitTimeSeconds $vars.namespaceToolOrchestration $vars.releaseNameToolOrchestration $vars.toolServiceReplicas
}

Write-Verbose 'Waiting for Code Dx...'
Wait-Deployment 'Code Dx Deployment' $vars.waitTimeSeconds $vars.namespaceCodeDx "$($vars.releaseNameCodeDx)-codedx" 1

if ($createCluster) {
	Write-Host "Done.`n`n***Note: '$($vars.workDir)' contains data that should be kept private.`n`n"
}

$portNum = 8080
$protocol = 'http'
if ($vars.useTLS) {
	$portNum = 8443
	$protocol = 'https'
}

$ipList = Get-IPv4AddressList $vars.codeDxDnsName

Write-Host "`n"
Write-Host "`nIf you configured an ingress, you can use it to access Code Dx.`nYou can also run the following command to make Code Dx available at $protocol`://$($vars.codeDxDnsName)`:$($vars.codeDxPortNumber)/codedx"
Write-Host ('pwsh -c "kubectl -n {3} port-forward --address {0},127.0.0.1 (kubectl -n {3} get pod -l app=codedx --field-selector=status.phase=Running -o name) {1}:{2}"' -f $ipList,$vars.codeDxPortNumber,$portNum,$namespaceCodeDx)

if ($vars.useTls) {
	Write-Host "Note that you may need to trust the root certificate located at $(join-path $HOME '.minikube/ca.crt')"
}
