param (
	[string]   $workDir = "$HOME/.k8s-codedx",

	[string]   $clusterCertificateAuthorityCertPath,
	[string]   $codeDxDnsName,
	[int]      $codeDxPortNumber = 8443,
	[int]      $waitTimeSeconds = 900,

	[int]      $dbVolumeSizeGiB = 32,
	[int]      $dbSlaveReplicaCount = 1,
	[int]      $dbSlaveVolumeSizeGiB = 32,
	[int]      $minioVolumeSizeGiB = 32,
	[int]      $codeDxVolumeSizeGiB = 32,
	[string]   $storageClassName = '',

	[string]   $imageCodeDxTomcat = 'codedxregistry.azurecr.io/codedx/codedx-tomcat:latest',
	[string]   $imageCodeDxTools = 'codedxregistry.azurecr.io/codedx/codedx-tools:latest',
	[string]   $imageCodeDxToolsMono = 'codedxregistry.azurecr.io/codedx/codedx-toolsmono:latest',
	[string]   $imageNewAnalysis = 'codedxregistry.azurecr.io/codedx/codedx-newanalysis:latest',
	[string]   $imageSendResults = 'codedxregistry.azurecr.io/codedx/codedx-results:latest',
	[string]   $imageSendErrorResults = 'codedxregistry.azurecr.io/codedx/codedx-error-results:latest',
	[string]   $imageToolService = 'codedxregistry.azurecr.io/codedx/codedx-tool-service:latest',
	[string]   $imagePreDelete = 'codedxregistry.azurecr.io/codedx/codedx-cleanup:latest',

	[int]      $toolServiceReplicas = 3,

	[bool]     $useTLS  = $true,
	[bool]     $usePSPs = $true,

	[bool]     $skipNetworkPolicies = $false,

	[string]   $ingressRegistrationEmailAddress = '',
	[string]   $ingressLoadBalancerIP = '',

	[string]   $namespaceToolOrchestration = 'cdx-svc',
	[string]   $namespaceCodeDx = 'cdx-app',
	[string]   $namespaceIngressController = 'nginx',
	[string]   $namespaceCertManager = 'cert-manager',
	[string]   $releaseNameCodeDx = 'codedx-app',
	[string]   $releaseNameToolOrchestration = 'toolsvc-codedx-tool-orchestration',

	[string]   $toolServiceApiKey = [guid]::newguid().toString(),

	[string]   $codedxAdminPwd,
	[string]   $minioAdminUsername = 'admin',
	[string]   $minioAdminPwd,
	[string]   $mariadbRootPwd,
	[string]   $mariadbReplicatorPwd,

	[string]   $dockerImagePullSecretName = 'codedx-docker-registry',
	[string]   $dockerConfigJson,

	[string]   $codedxRepo = 'https://codedx.github.io/codedx-kubernetes',

	[int]      $kubeApiTargetPort = 443,

	[string[]] $extraCodeDxValuesPaths = @(),

	[switch]   $skipToolOrchestration,

	[management.automation.scriptBlock] $provisionNetworkPolicy,
	[management.automation.scriptBlock] $provisionIngress
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. (join-path $PSScriptRoot './common/helm.ps1')
. (join-path $PSScriptRoot './common/codedx.ps1')

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

if ($codeDxDnsName -eq '') { $codeDxDnsName = Read-Host -Prompt 'Enter Code Dx domain name (e.g., www.codedx.io)' }
if ($clusterCertificateAuthorityCertPath -eq '') { $clusterCertificateAuthorityCertPath = Read-Host -Prompt 'Enter path to cluster CA certificate' }
if ((-not $skipToolOrchestration) -and $minioAdminUsername -eq '') { $minioAdminUsername = Get-SecureStringText 'Enter a username for the MinIO admin account' 5 }
if ((-not $skipToolOrchestration) -and $minioAdminPwd -eq '') { $minioAdminPwd = Get-SecureStringText 'Enter a password for the MinIO admin account' 8 }
if ($mariadbRootPwd -eq '') { $mariadbRootPwd = Get-SecureStringText 'Enter a password for the MariaDB root user' 0 }
if ($mariadbReplicatorPwd -eq '') { $mariadbReplicatorPwd = Get-SecureStringText 'Enter a password for the MariaDB replicator user' 0 }
if ($codedxAdminPwd -eq '') { $codedxAdminPwd = Get-SecureStringText 'Enter a password for the Code Dx admin account' 6 }
if ((-not $skipToolOrchestration) -and $toolServiceApiKey -eq '') { $toolServiceApiKey = Get-SecureStringText 'Enter an API key for the Code Dx Tool Orchestration service' 8 }
if ($dockerImagePullSecretName -ne '' -and $dockerConfigJson -eq '') { $dockerConfigJson = Get-SecureStringText 'Enter a dockerconfigjson value for your private Docker registry' 0 }

if (-not (test-path $clusterCertificateAuthorityCertPath -PathType Leaf)) {
	write-error "Unable to continue because path '$clusterCertificateAuthorityCertPath' cannot be found."
}

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
$namespaceCodeDx,$namespaceIngressController,$namespaceCertManager | ForEach-Object {
	Wait-AllRunningPods "Cluster Ready (namespace $_)" $waitTimeSeconds $_	
}

if (-not $skipToolOrchestration) {
	Wait-AllRunningPods "Cluster Ready (namespace $namespaceToolOrchestration)" $waitTimeSeconds $namespaceToolOrchestration
}

Write-Verbose 'Adding Helm repository...'
Add-HelmRepo 'codedx' $codedxRepo

$configureIngress = $ingressRegistrationEmailAddress -ne ''
if ($configureIngress) {

	Write-Verbose 'Adding nginx Ingress...'
	$priorityValuesFile = 'nginx-ingress-priority.yaml'
	if ($provisionIngress -eq $null) {
		if ($ingressLoadBalancerIP -ne '') {
			Add-NginxIngressLoadBalancerIP $ingressLoadBalancerIP $namespaceIngressController $waitTimeSeconds 'nginx-ingress.yaml' $priorityValuesFile
		} else {
			Add-NginxIngress $namespaceIngressController $waitTimeSeconds '' $priorityValuesFile
		}
	} else {
		& $provisionIngress
	}

	Write-Verbose 'Adding Cert Manager...'
	Add-CertManager $namespaceCertManager $namespaceCodeDx `
		$ingressRegistrationEmailAddress 'staging-cluster-issuer.yaml' 'production-cluster-issuer.yaml' `
		'cert-manager-role.yaml' 'cert-manager-role-binding.yaml' 'cert-manager-http-solver-role-binding.yaml' `
		$waitTimeSeconds
}

Write-Verbose 'Fetching Code Dx Helm charts...'
Remove-Item .\codedx-kubernetes -Force -Confirm:$false -Recurse -ErrorAction SilentlyContinue
Invoke-GitClone 'https://github.com/codedx/codedx-kubernetes' 'develop'

Write-Verbose 'Deploying Code Dx with Tool Orchestration disabled...'
New-CodeDxDeployment $codeDxDnsName $workDir $waitTimeSeconds `
	$clusterCertificateAuthorityCertPath `
	$namespaceCodeDx $releaseNameCodeDx $codedxAdminPwd $imageCodeDxTomcat $dockerImagePullSecretName $dockerConfigJson `
	$mariadbRootPwd $mariadbReplicatorPwd `
	$dbVolumeSizeGiB `
	$dbSlaveReplicaCount $dbSlaveVolumeSizeGiB `
	$codeDxVolumeSizeGiB `
	$storageClassName `
	$extraCodeDxValuesPaths `
	$namespaceIngressController `
	-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS -configureIngress:$configureIngress

if (-not $skipToolOrchestration) {

	Write-Verbose 'Deploying Tool Orchestration...'
	New-ToolOrchestrationDeployment $workDir $waitTimeSeconds `
		$clusterCertificateAuthorityCertPath `
		$namespaceToolOrchestration $namespaceCodeDx $releaseNameCodeDx $toolServiceReplicas `
		$minioAdminUsername $minioAdminPwd $toolServiceApiKey `
		$imageCodeDxTools $imageCodeDxToolsMono `
		$imageNewAnalysis $imageSendResults $imageSendErrorResults $imageToolService $imagePreDelete `
		$dockerImagePullSecretName $dockerConfigJson `
		$minioVolumeSizeGiB $storageClassName `
		$kubeApiTargetPort `
		-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS

	Write-Verbose 'Updating Code Dx deployment by enabling Tool Orchestration...'
	$protocol = 'http'
	if ($useTLS) {
		$protocol = 'https'
	}
	Set-UseToolOrchestration $workDir `
		$waitTimeSeconds `
		$clusterCertificateAuthorityCertPath `
		$namespaceToolOrchestration $namespaceCodeDx `
		"$protocol`://$releaseNameToolOrchestration.$namespaceToolOrchestration.svc.cluster.local:3333" $toolServiceApiKey `
		$releaseNameCodeDx -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS
}

if ($usePSPs) {
	Write-Verbose 'Adding default PSP...'
	Add-DefaultPodSecurityPolicy 'psp.yaml' 'psp-role.yaml' 'psp-role-binding.yaml'
}
