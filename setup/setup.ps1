<#PSScriptInfo
.VERSION 1.0.2
.GUID 47733b28-676e-455d-b7e8-88362f442aa3
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script uses Helm to install and configure Code Dx and Tool Orchestration 
on a Kubernetes cluster. The setup.ps1 script located here gets called indirectly 
by the setup.ps1 scripts in the provider-specific folders. See the README files 
under aws, azure, and minikube for more details
#>

param (
	[string]   $workDir = "$HOME/.k8s-codedx",
	[string]   $kubeContextName = '',

	[string]   $clusterCertificateAuthorityCertPath,
	[string]   $codeDxDnsName,
	[int]      $codeDxServicePortNumber = 9090,
	[int]      $codeDxTlsServicePortNumber = 9443,
	[int]      $waitTimeSeconds = 900,

	[int]      $dbVolumeSizeGiB = 32,
	[int]      $dbSlaveReplicaCount = 1,
	[int]      $dbSlaveVolumeSizeGiB = 32,
	[int]      $minioVolumeSizeGiB = 32,
	[int]      $codeDxVolumeSizeGiB = 32,
	[string]   $storageClassName = '',

	[string]   $codeDxMemoryReservation = '',
	[string]   $dbMasterMemoryReservation = '',
	[string]   $dbSlaveMemoryReservation = '',
	[string]   $toolServiceMemoryReservation = '',
	[string]   $minioMemoryReservation = '',
	[string]   $workflowMemoryReservation = '',
	[string]   $nginxMemoryReservation = '',

	[string]   $codeDxCPUReservation = '',
	[string]   $dbMasterCPUReservation = '',
	[string]   $dbSlaveCPUReservation = '',
	[string]   $toolServiceCPUReservation = '',
	[string]   $minioCPUReservation = '',
	[string]   $workflowCPUReservation = '',
	[string]   $nginxCPUReservation = '',

	[string]   $codeDxEphemeralStorageReservation = '2Gi',
	[string]   $dbMasterEphemeralStorageReservation = '',
	[string]   $dbSlaveEphemeralStorageReservation = '',
	[string]   $toolServiceEphemeralStorageReservation = '',
	[string]   $minioEphemeralStorageReservation = '',
	[string]   $workflowEphemeralStorageReservation = '',
	[string]   $nginxEphemeralStorageReservation = '',

	[string]   $imageCodeDxTomcat = 'codedx/codedx-tomcat:v5.0.3',
	[string]   $imageCodeDxTools = 'codedx/codedx-tools:v1.0.0',
	[string]   $imageCodeDxToolsMono = 'codedx/codedx-toolsmono:v1.0.0',
	[string]   $imageNewAnalysis = 'codedx/codedx-newanalysis:v1.0.0',
	[string]   $imageSendResults = 'codedx/codedx-results:v1.0.0',
	[string]   $imageSendErrorResults = 'codedx/codedx-error-results:v1.0.0',
	[string]   $imageToolService = 'codedx/codedx-tool-service:v1.0.1',
	[string]   $imagePreDelete = 'codedx/codedx-cleanup:v1.0.0',

	[int]      $toolServiceReplicas = 3,

	[bool]     $useTLS  = $true,
	[bool]     $usePSPs = $true,

	[bool]     $skipNetworkPolicies = $false,

	[bool]     $nginxIngressControllerInstall = $true,
	[string]   $nginxIngressControllerLoadBalancerIP = '',

	[bool]     $letsEncryptCertManagerInstall = $true,
	[string]   $letsEncryptCertManagerRegistrationEmailAddress = '',
	[string]   $letsEncryptCertManagerClusterIssuer = 'letsencrypt-staging',
	[string]   $letsEncryptCertManagerNamespace = 'cert-manager',

	[string]   $serviceTypeCodeDx = '',
	[string[]] $serviceAnnotationsCodeDx = @(),

	[bool]     $ingressEnabled = $true,
	[bool]     $ingressAssumesNginx = $true,
	[string[]] $ingressAnnotationsCodeDx = @(),

	[string]   $namespaceToolOrchestration = 'cdx-svc',
	[string]   $namespaceCodeDx = 'cdx-app',
	[string]   $namespaceIngressController = 'nginx',
	[string]   $releaseNameCodeDx = 'codedx',
	[string]   $releaseNameToolOrchestration = 'codedx-tool-orchestration',

	[string]   $toolServiceApiKey = [guid]::newguid().toString(),

	[string]   $codedxAdminPwd,
	[string]   $minioAdminUsername = 'admin',
	[string]   $minioAdminPwd,
	[string]   $mariadbRootPwd,
	[string]   $mariadbReplicatorPwd,

	[string]   $caCertsFilePwd = 'changeit',
	[string]   $caCertsFileNewPwd = '',
	
	[string[]] $extraCodeDxChartFilesPaths = @(),
	[string[]] $extraCodeDxTrustedCaCertPaths = @(),

	[string]   $dockerImagePullSecretName = '',
	[string]   $dockerRegistry,
	[string]   $dockerRegistryUser,
	[string]   $dockerRegistryPwd,

	[string]   $codedxHelmRepo = 'https://codedx.github.io/codedx-kubernetes',
	
	[string]   $codedxGitRepo = 'https://github.com/codedx/codedx-kubernetes.git',
	[string]   $codedxGitRepoBranch = 'master',

	[int]      $kubeApiTargetPort = 443,

	[string[]] $extraCodeDxValuesPaths = @(),
	[string[]] $extraToolOrchestrationValuesPath = @(),
	
	[switch]   $skipDatabase,
	[switch]   $skipToolOrchestration,

	[management.automation.scriptBlock] $provisionNetworkPolicy,
	[management.automation.scriptBlock] $provisionIngressController
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. (join-path $PSScriptRoot './common/helm.ps1')
. (join-path $PSScriptRoot './common/codedx.ps1')
. (join-path $PSScriptRoot './common/keytool.ps1')

function Write-ImportantNote([string] $message) {
	Write-Host ('NOTE: {0}' -f $message) -ForegroundColor Red -BackgroundColor Black
}

if (-not (Test-IsCore)) {
	write-error 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
}

'helm','kubectl','openssl','git','keytool' | foreach-object {
	if ($null -eq (Get-AppCommandPath $_)) {
		write-error "Unable to continue because $_ cannot be found. Is $_ installed and included in your PATH?"
	}
}

$helmVersionMatch = helm version | select-string 'Version:"v3'
if ($null -eq $helmVersionMatch) {
	write-error 'Unable to continue because helm (v3) was not found. Is it in your PATH?'
}

if ($kubeContextName -ne '') {
	Set-KubectlContext $kubeContextName
	Write-Verbose "Using kubeconfig context entry named $(Get-KubectlContext)"
}

if ($codeDxDnsName -eq '') { $codeDxDnsName = Read-Host -Prompt 'Enter Code Dx domain name (e.g., www.codedx.io)' }
if ($clusterCertificateAuthorityCertPath -eq '') { $clusterCertificateAuthorityCertPath = Read-Host -Prompt 'Enter path to cluster CA certificate' }
if ((-not $skipToolOrchestration) -and $minioAdminUsername -eq '') { $minioAdminUsername = Read-HostSecureText 'Enter a username for the MinIO admin account' 5 }
if ((-not $skipToolOrchestration) -and $minioAdminPwd -eq '') { $minioAdminPwd = Read-HostSecureText 'Enter a password for the MinIO admin account' 8 }
if ($codedxAdminPwd -eq '') { $codedxAdminPwd = Read-HostSecureText 'Enter a password for the Code Dx admin account' 6 }
if ((-not $skipToolOrchestration) -and $toolServiceApiKey -eq '') { $toolServiceApiKey = Read-HostSecureText 'Enter an API key for the Code Dx Tool Orchestration service' 8 }
if ($caCertsFileNewPwd -ne '' -and $caCertsFileNewPwd.length -lt 6) { $caCertsFileNewPwd = Read-HostSecureText 'Enter a password to protect the cacerts file' 6 }

if ($skipDatabase) {
	Write-ImportantNote 'Since you''re skipping the database installation, you must specify codedxProps.dbconnection.externalDbUrl in an extra values.yaml file.'
}
else {
	if ($mariadbRootPwd -eq '') { $mariadbRootPwd = Read-HostSecureText 'Enter a password for the MariaDB root user' 0 }
	if ($mariadbReplicatorPwd -eq '') { $mariadbReplicatorPwd = Read-HostSecureText 'Enter a password for the MariaDB replicator user' 0 }
}

if ($letsEncryptCertManagerInstall){

	if ($letsEncryptCertManagerRegistrationEmailAddress -eq '') { 
		$letsEncryptCertManagerRegistrationEmailAddress = Read-HostText 'Enter an email address for the Let''s Encrypt registration' 
	}
	if ($letsEncryptCertManagerClusterIssuer -eq '') { 
		$letsEncryptCertManagerClusterIssuer = Read-HostText 'Enter a cluster issuer name for Let''s Encrypt' 
	}
}

if ($dockerImagePullSecretName -ne '') {
	
	if ($dockerRegistry -eq '') {
		$dockerRegistry = Read-HostText 'Enter private Docker registry' 1
	}
	if ($dockerRegistryUser -eq '') {
		$dockerRegistryUser = Read-HostText "Enter a docker username for $dockerRegistry" 1
	}
	if ($dockerRegistryPwd -eq '') {
		$dockerRegistryPwd = Read-HostSecureText "Enter a docker password for $dockerRegistry" 1
	}
}

if (-not (test-path $clusterCertificateAuthorityCertPath -PathType Leaf)) {
	write-error "Unable to continue because path '$clusterCertificateAuthorityCertPath' cannot be found."
}

if ($dbSlaveReplicaCount -eq 0) {
	Write-ImportantNote 'Skipping slave database instances and the database backup process they provide.'
}

$workDir = join-path $workDir "$releaseNameCodeDx-$releaseNameToolOrchestration"
Write-Verbose "Creating directory $workDir..."
New-Item -Type Directory $workDir -Force

Write-Verbose "Switching to directory $workDir..."
Push-Location $workDir

$useNetworkPolicies = -not $skipNetworkPolicies
if ($useNetworkPolicies -and $provisionNetworkPolicy -ne $null) {

	Write-Verbose "Adding network policy provider..."
	& $provisionNetworkPolicy $waitTimeSeconds
}

Write-Verbose 'Waiting for running pods...'
$namespaceCodeDx,$namespaceIngressController,$letsEncryptCertManagerNamespace | ForEach-Object {
	if (Test-Namespace $_) {
		Wait-AllRunningPods "Cluster Ready (namespace $_)" $waitTimeSeconds $_	
	}
}

if (-not $skipToolOrchestration) {
	if (Test-Namespace $namespaceToolOrchestration) {
		Wait-AllRunningPods "Cluster Ready (namespace $namespaceToolOrchestration)" $waitTimeSeconds $namespaceToolOrchestration
	}
}

Write-Verbose 'Adding Helm repository...'
Add-HelmRepo 'codedx' $codedxHelmRepo


if ($null -ne $provisionIngressController) {
	& $provisionIngressController
}

if ($nginxIngressControllerInstall) {

	Write-Verbose 'Adding nginx Ingress...'
	$priorityValuesFile = 'nginx-ingress-priority.yaml'

	if ($nginxIngressControllerLoadBalancerIP -ne '') {
		Add-NginxIngressLoadBalancerIP $nginxIngressControllerLoadBalancerIP $namespaceIngressController $waitTimeSeconds 'nginx-ingress.yaml' $priorityValuesFile $releaseNameCodeDx $nginxCPUReservation $nginxMemoryReservation $nginxEphemeralStorageReservation -enablePSPs:$usePSPs
	} else {
		Add-NginxIngress $namespaceIngressController $waitTimeSeconds '' $priorityValuesFile $releaseNameCodeDx $nginxCPUReservation $nginxMemoryReservation $nginxEphemeralStorageReservation
	}

	$ingressAnnotationsCodeDx += "nginx.ingress.kubernetes.io/proxy-read-timeout: '3600'"
	$ingressAnnotationsCodeDx += "nginx.ingress.kubernetes.io/proxy-body-size: '0'"
}

if ($letsEncryptCertManagerInstall) {

	Write-Verbose 'Adding Let''s Encrypt Cert Manager...'
	Add-LetsEncryptCertManager $letsEncryptCertManagerNamespace $namespaceCodeDx `
		$letsEncryptCertManagerRegistrationEmailAddress 'staging-cluster-issuer.yaml' 'production-cluster-issuer.yaml' `
		'cert-manager-role.yaml' 'cert-manager-role-binding.yaml' 'cert-manager-http-solver-role-binding.yaml' `
		$waitTimeSecond -enablePSPs:$usePSPss

	$ingressAnnotationsCodeDx += "kubernetes.io/tls-acme: 'true'"
	$ingressAnnotationsCodeDx += "cert-manager.io/cluster-issuer: '$letsEncryptCertManagerClusterIssuer'"
}

Write-Verbose 'Fetching Code Dx Helm charts...'
Remove-Item .\codedx-kubernetes -Force -Confirm:$false -Recurse -ErrorAction SilentlyContinue
Invoke-GitClone $codedxGitRepo $codedxGitRepoBranch

if ($extraCodeDxChartFilesPaths.Count -gt 0) {
	Copy-Item $extraCodeDxChartFilesPaths .\codedx-kubernetes\codedx
}

if (-not $nginxIngressControllerInstall -and $null -eq $provisionIngressController) {
	$namespaceIngressController = ''
}

Write-Verbose 'Deploying Code Dx with Tool Orchestration disabled...'
New-CodeDxDeployment $codeDxDnsName $codeDxServicePortNumber $codeDxTlsServicePortNumber $workDir $waitTimeSeconds `
	$clusterCertificateAuthorityCertPath `
	$namespaceCodeDx $releaseNameCodeDx $codedxAdminPwd $imageCodeDxTomcat `
	$dockerImagePullSecretName `
	$dockerRegistry $dockerRegistryUser $dockerRegistryPwd `
	$mariadbRootPwd $mariadbReplicatorPwd `
	$dbVolumeSizeGiB `
	$dbSlaveReplicaCount $dbSlaveVolumeSizeGiB `
	$codeDxVolumeSizeGiB `
	$storageClassName `
	$codeDxMemoryReservation $dbMasterMemoryReservation $dbSlaveMemoryReservation `
	$codeDxCPUReservation $dbMasterCPUReservation $dbSlaveCPUReservation `
	$codeDxEphemeralStorageReservation $dbMasterEphemeralStorageReservation $dbSlaveEphemeralStorageReservation `
	$extraCodeDxValuesPaths `
	$serviceTypeCodeDx $serviceAnnotationsCodeDx `
	$namespaceIngressController `
	$ingressAnnotationsCodeDx `
	-ingressEnabled:$ingressEnabled -ingressAssumesNginx:$ingressAssumesNginx `
	-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS -skipDatabase:$skipDatabase

$caCertPaths = $extraCodeDxTrustedCaCertPaths
if ($useTLS -and -not $skipToolOrchestration) {
	$caCertPaths += $clusterCertificateAuthorityCertPath
}

if ($caCertPaths.count -gt 0) {
	Set-TrustedCerts $workDir `
		$waitTimeSeconds `
		$namespaceCodeDx `
		$releaseNameCodeDx `
		$extraCodeDxValuesPaths `
		$caCertsFilePwd `
		$caCertsFileNewPwd `
		$caCertPaths
}

if (-not $skipToolOrchestration) {

	Write-Verbose 'Deploying Tool Orchestration...'
	New-ToolOrchestrationDeployment $workDir $waitTimeSeconds `
		$clusterCertificateAuthorityCertPath `
		$namespaceToolOrchestration $namespaceCodeDx `
		$releaseNameToolOrchestration $releaseNameCodeDx `
		$codeDxServicePortNumber $codeDxTlsServicePortNumber `
		$toolServiceReplicas `
		$minioAdminUsername $minioAdminPwd $toolServiceApiKey `
		$imageCodeDxTools $imageCodeDxToolsMono `
		$imageNewAnalysis $imageSendResults $imageSendErrorResults $imageToolService $imagePreDelete `
		$dockerImagePullSecretName `
		$dockerRegistry $dockerRegistryUser $dockerRegistryPwd `
		$minioVolumeSizeGiB $storageClassName `
		$toolServiceMemoryReservation $minioMemoryReservation $workflowMemoryReservation `
		$toolServiceCPUReservation $minioCPUReservation $workflowCPUReservation `
		$toolServiceEphemeralStorageReservation $minioEphemeralStorageReservation $workflowEphemeralStorageReservation `
		$kubeApiTargetPort `
		$extraToolOrchestrationValuesPath `
		-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS

	Write-Verbose 'Updating Code Dx deployment by enabling Tool Orchestration...'
	$protocol = 'http'
	if ($useTLS) {
		$protocol = 'https'
	}

	$toolOrchestrationFullName = Get-CodeDxToolOrchestrationChartFullName $releaseNameToolOrchestration
	Set-UseToolOrchestration $workDir `
		$waitTimeSeconds `
		$clusterCertificateAuthorityCertPath `
		$namespaceToolOrchestration $namespaceCodeDx `
		"$protocol`://$toolOrchestrationFullName.$namespaceToolOrchestration.svc.cluster.local:3333" $toolServiceApiKey `
		$releaseNameCodeDx `
		$caCertsFilePwd $caCertsFileNewPwd `
		$extraCodeDxValuesPaths `
		-enableNetworkPolicies:$useNetworkPolicies
}


