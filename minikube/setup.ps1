# This script uses Helm to install and configure Code Dx and Tool Orchestration on a minikube cluster.
#
# The following tools must be installed and included in your PATH prior to running this script:
#
# 1 minikube
# 2 helm tool
# 3 kubectl
# 4 openssl
# 5 git
# 6 keytool
#
# 7 socat (when using $vmDriver 'none')
#
param (
	[string]   $codeDxDnsName = (hostname),
	[int]      $codeDxPortNumber = 8443,
	[string]   $k8sVersion = 'v1.14.6',
	[string]   $minikubeProfile = 'minikube-1-14-6',
	[int]      $nodeCPUs = 4,
	[string]   $nodeMemory = '16g',
	[int]      $waitTimeSeconds = 600,
	[string]   $vmDriver = 'virtualbox',

	[int]      $dbVolumeSizeGiB = 32,
	[int]      $minioVolumeSizeGiB = 32,
	[int]      $codeDxVolumeSizeGiB = 32,

	[string]   $imagePullSecretName = 'codedx-docker-registry',
	[string]   $imageCodeDxTomcat = 'codedxregistry.azurecr.io/codedx/codedx-tomcat:latest',
	[string]   $imageCodeDxTools = 'codedxregistry.azurecr.io/codedx/codedx-tools:latest',
	[string]   $imageCodeDxToolsMono = 'codedxregistry.azurecr.io/codedx/codedx-toolsmono:latest',
	[string]   $imageNewAnalysis = 'codedxregistry.azurecr.io/codedx/codedx-newanalysis:latest',
	[string]   $imageSendResults = 'codedxregistry.azurecr.io/codedx/codedx-results:latest',
	[string]   $imageSendErrorResults = 'codedxregistry.azurecr.io/codedx/codedx-error-results:latest',
	[string]   $imageToolService = 'codedxregistry.azurecr.io/codedx/codedx-tool-service:latest',

	[int]      $toolServiceReplicas = 3,

	[bool]     $useTLS  = $true,
	[bool]     $usePSPs = $true,
	[bool]     $useNetworkPolicies = $true,

	[string]   $namespaceToolOrchestration = 'cdx-svc',
	[string]   $namespaceCodeDx = 'cdx-app',
	[string]   $releaseNameCodeDx = 'codedx-app',
	[string]   $releaseNameToolOrchestration = 'toolsvc-codedx-tool-orchestration',

	[string]   $toolServiceApiKey = [guid]::newguid().toString(),
	[string]   $codedxAdminPwd,
	[string]   $minioAdminUsername,
	[string]   $minioAdminPwd,
	[string]   $mariadbRootPwd,
	[string]   $mariadbReplicatorPwd,

	[string]   $dockerConfigJson,

	[string[]] $extraCodeDxValuesPaths = @(),
	[switch]   $pauseForClusterConfig
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. (join-path $PSScriptRoot helm.ps1)
. (join-path $PSScriptRoot codedx.ps1)

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


'minikube','helm','kubectl','openssl','git','keytool' | foreach-object {
	if ($null -eq (Get-AppCommandPath $_)) {
		write-error "Unable to continue because $_ cannot be found. Is $_ installed and included in your PATH?"
	}
}

$workDir = "$HOME/.codedx-$minikubeProfile"
$varsPath = Join-Path $workDir 'vars.csv'

$createCluster = -not (Test-MinikubeProfile $minikubeProfile $vmDriver $k8sVersion)

if ($createCluster) {

	if ($minioAdminUsername -eq '') { $minioAdminUsername = Get-SecureStringText 'Enter a username for the MinIO admin account' 5 }
	if ($minioAdminPwd -eq '') { $minioAdminPwd = Get-SecureStringText 'Enter a password for the MinIO admin account' 8 }
	if ($mariadbRootPwd -eq '') { $mariadbRootPwd = Get-SecureStringText 'Enter a password for the MariaDB root user' 0 }
	if ($mariadbReplicatorPwd -eq '') { $mariadbReplicatorPwd = Get-SecureStringText 'Enter a password for the MariaDB replicator user' 0 }
	if ($codedxAdminPwd -eq '') { $codedxAdminPwd = Get-SecureStringText 'Enter a password for the Code Dx admin account' 6 }
	if ($toolServiceApiKey -eq '') { $toolServiceApiKey = Get-SecureStringText 'Enter an API key for the Code Dx Tool Orchestration service' 8 }
	if ($dockerConfigJson -eq '') { $dockerConfigJson = Get-SecureStringText 'Enter a dockerconfigjson value for your private Docker registry' 0 }	

	Write-Verbose "Creating new minikube cluster using profile $minikubeProfile..."

	Write-Verbose "Creating directory $workDir..."
	New-Item -Type Directory $workDir -Force

	Write-Verbose "Switching to directory $workDir..."
	Push-Location $workDir

	$extraConfig = @()
	if ($vmDriver -eq 'none') {
		$extraConfig = '--extra-config=kubeadm.ignore-preflight-errors=SystemVerification','--extra-config=kubelet.resolv-conf=/run/systemd/resolve/resolv.conf'
	}

	Write-Verbose "Determining disk size requirement..."
	$minikubeDiskSizeGiB = 20
	$nodeDiskSize = [string](2 * $dbVolumeSizeGiB + $minioVolumeSizeGiB + $codeDxVolumeSizeGiB + $minikubeDiskSizeGiB) + 'g'

	Write-Verbose "Profile does not exist. Creating new minikube profile named $minikubeProfile for k8s version $k8sVersion..."
	New-MinikubeCluster $minikubeProfile $k8sVersion $vmDriver $nodeCPUs $nodeMemory $nodeDiskSize $extraConfig

	if ($pauseForClusterConfig) {
		Write-Verbose "Pausing to provide opportunity for cluster customizations..."
		Read-Host -Prompt "Apply any custom cluster configuration and then press Enter to continue setup"
	}

	if ($useNetworkPolicies) {
		Write-Verbose "Adding Cilium network policy provider..."
		Add-CiliumNetworkPolicyProvider $minikubeProfile $waitTimeSeconds $vmDriver
	}

	Write-Verbose 'Stopping minikube cluster...'
	Stop-MinikubeCluster $minikubeProfile

	Write-Verbose 'Starting minikube cluster...'
	Start-MinikubeCluster $minikubeProfile $k8sVersion $vmDriver $waitTimeSeconds -useNetworkPolicy:$useNetworkPolicies $extraConfig

	Write-Verbose 'Waiting for running pods...'
	Wait-AllRunningPods 'Start Minikube Cluster' $waitTimeSeconds

	Write-Verbose 'Initializing Helm and adding repositories...'
	Add-Helm $waitTimeSeconds
	Add-HelmRepo 'minio' https://codedx.github.io/charts
	Add-HelmRepo 'argo' https://argoproj.github.io/argo-helm

	Write-Verbose 'Adding Ingress Addon'
	Add-IngressAddOn $minikubeProfile $waitTimeSeconds

	Write-Verbose 'Fetching Code Dx Helm charts...'
	Remove-Item .\codedx-kubernetes -Force -Confirm:$false -Recurse -ErrorAction SilentlyContinue
	Invoke-GitClone 'https://github.com/codedx/codedx-kubernetes' 'develop'

	Write-Verbose 'Deploying Code Dx with Tool Orchestration disabled...'
	New-CodeDxDeployment $codeDxDnsName $workDir $waitTimeSeconds $namespaceCodeDx $releaseNameCodeDx $codedxAdminPwd $imageCodeDxTomcat $imagePullSecretName $dockerConfigJson `
		$mariadbRootPwd $mariadbReplicatorPwd `
		$dbVolumeSizeGiB $codeDxVolumeSizeGiB `
		$extraCodeDxValuesPaths `
		-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS

	Write-Verbose 'Deploying Tool Orchestration...'
	New-ToolOrchestrationDeployment $workDir $waitTimeSeconds $namespaceToolOrchestration $namespaceCodeDx $releaseNameCodeDx $toolServiceReplicas `
		$minioAdminUsername $minioAdminPwd $toolServiceApiKey `
		$imageCodeDxTools $imageCodeDxToolsMono `
		$imageNewAnalysis $imageSendResults $imageSendErrorResults $imageToolService `
		$imagePullSecretName $dockerConfigJson $minioVolumeSizeGiB `
		-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS

	Write-Verbose 'Updating Code Dx deployment by enabling Tool Orchestration...'
	$protocol = 'http'
	if ($useTLS) {
		$protocol = 'https'
	}
	Set-UseToolOrchestration $workDir `
		$waitTimeSeconds `
		$namespaceToolOrchestration $namespaceCodeDx `
		"$protocol`://$releaseNameToolOrchestration.$namespaceToolOrchestration.svc.cluster.local:3333" $toolServiceApiKey `
		$releaseNameCodeDx -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS

	if ($usePSPs) {
		Write-Verbose 'Adding default PSP...'
		Add-DefaultPodSecurityPolicy 'psp.yaml' 'psp-role.yaml' 'psp-role-binding.yaml'
	}

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

Write-Verbose 'Waiting for Tool Orchestration deployment...'
Wait-Deployment 'Tool Orchestration Deployment' $vars.waitTimeSeconds $vars.namespaceToolOrchestration $vars.releaseNameToolOrchestration $vars.toolServiceReplicas

Write-Verbose 'Waiting for Code Dx...'
Wait-Deployment 'Code Dx Deployment' $vars.waitTimeSeconds $vars.namespaceCodeDx "$($vars.releaseNameCodeDx)-codedx" 1

if ($createCluster) {
	Write-Host "Done.`n`n***Note: '$($vars.workDir)' contains values.yaml data that should be kept private.`n`n"
}

$portNum = 8080
$protocol = 'http'
if ($vars.useTLS) {
	$portNum = 8443
	$protocol = 'https'
}

$ipList = Get-IPv4AddressList $vars.codeDxDnsName

Write-Host "`nRun the following command to make Code Dx available at $protocol`://$($vars.codeDxDnsName)`:$($vars.codeDxPortNumber)/codedx"
Write-Host ('pwsh -c "kubectl -n cdx-app port-forward --address {0} (kubectl -n cdx-app get pod -l app=codedx --field-selector=status.phase=Running -o name) {1}:{2}"' -f $ipList,$vars.codeDxPortNumber,$portNum)

if ($vars.useTls) {
	Write-Host "Note that you may need to trust the root certificate located at $(join-path $HOME '.minikube/ca.crt')"
}
