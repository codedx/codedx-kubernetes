<#PSScriptInfo
.VERSION 1.2.2
.GUID 47733b28-676e-455d-b7e8-88362f442aa3
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script uses Helm to install and configure Code Dx and Tool Orchestration 
on a Kubernetes cluster. Use the guided-setup.ps1 script to specify the 
parameters for this script.
#>

param (
	[string]   $workDir = "$HOME/.k8s-codedx",
	[string]   $kubeContextName,

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
	[string]   $storageClassName,

	[string]   $codeDxMemoryReservation,
	[string]   $dbMasterMemoryReservation,
	[string]   $dbSlaveMemoryReservation,
	[string]   $toolServiceMemoryReservation,
	[string]   $minioMemoryReservation,
	[string]   $workflowMemoryReservation,
	[string]   $nginxMemoryReservation,

	[string]   $codeDxCPUReservation,
	[string]   $dbMasterCPUReservation,
	[string]   $dbSlaveCPUReservation,
	[string]   $toolServiceCPUReservation,
	[string]   $minioCPUReservation,
	[string]   $workflowCPUReservation,
	[string]   $nginxCPUReservation,

	[string]   $codeDxEphemeralStorageReservation = '2Gi',
	[string]   $dbMasterEphemeralStorageReservation,
	[string]   $dbSlaveEphemeralStorageReservation,
	[string]   $toolServiceEphemeralStorageReservation,
	[string]   $minioEphemeralStorageReservation,
	[string]   $workflowEphemeralStorageReservation,
	[string]   $nginxEphemeralStorageReservation,

	[string]   $imageCodeDxTomcat = 'codedx/codedx-tomcat:v5.1.1',
	[string]   $imageCodeDxTools = 'codedx/codedx-tools:v1.0.5',
	[string]   $imageCodeDxToolsMono = 'codedx/codedx-toolsmono:v1.0.5',
	[string]   $imageNewAnalysis = 'codedx/codedx-newanalysis:v1.0.0',
	[string]   $imageSendResults = 'codedx/codedx-results:v1.0.0',
	[string]   $imageSendErrorResults = 'codedx/codedx-error-results:v1.0.0',
	[string]   $imageToolService = 'codedx/codedx-tool-service:v1.0.2',
	[string]   $imagePreDelete = 'codedx/codedx-cleanup:v1.0.0',

	[int]      $toolServiceReplicas = 3,

	[switch]   $skipTLS,
	[switch]   $skipPSPs,
	[switch]   $skipNetworkPolicies,

	[switch]   $skipNginxIngressControllerInstall,
	[string]   $nginxIngressControllerLoadBalancerIP,
	[string]   $nginxIngressControllerNamespace = 'nginx',

	[switch]   $skipLetsEncryptCertManagerInstall,
	[string]   $letsEncryptCertManagerRegistrationEmailAddress,
	[string]   $letsEncryptCertManagerClusterIssuer = 'letsencrypt-staging',
	[string]   $letsEncryptCertManagerNamespace = 'cert-manager',

	[string]   $serviceTypeCodeDx,
	[hashtable]$serviceAnnotationsCodeDx = @{},

	[switch]   $skipIngressEnabled,
	[switch]   $skipIngressAssumesNginx,
	[hashtable]$ingressAnnotationsCodeDx = @{},

	[string]   $namespaceToolOrchestration = 'cdx-svc',
	[string]   $namespaceCodeDx = 'cdx-app',
	[string]   $releaseNameCodeDx = 'codedx',
	[string]   $releaseNameToolOrchestration = 'codedx-tool-orchestration',

	[string]   $toolServiceApiKey,

	[string]   $codedxAdminPwd,
	[string]   $minioAdminUsername = 'admin',
	[string]   $minioAdminPwd,
	[string]   $mariadbRootPwd,
	[string]   $mariadbReplicatorPwd,

	[string]   $caCertsFilePath,
	[string]   $caCertsFilePwd,
	[string]   $caCertsFileNewPwd,
	
	[string[]] $extraCodeDxChartFilesPaths = @(),
	[string[]] $extraCodeDxTrustedCaCertPaths = @(),

	[string]   $dockerImagePullSecretName,
	[string]   $dockerRegistry,
	[string]   $dockerRegistryUser,
	[string]   $dockerRegistryPwd,

	[string]   $codedxHelmRepo = 'https://codedx.github.io/codedx-kubernetes',
	
	[string]   $codedxGitRepo = 'https://github.com/codedx/codedx-kubernetes.git',
	[string]   $codedxGitRepoBranch = 'v1.3.2',

	[int]      $kubeApiTargetPort = 443,

	[string[]] $extraCodeDxValuesPaths = @(),
	[string[]] $extraToolOrchestrationValuesPath = @(),

	[switch]   $skipDatabase,
	[string]   $externalDatabaseHost,
	[int]      $externalDatabasePort = 3306,
	[string]   $externalDatabaseName,
	[string]   $externalDatabaseUser,
	[string]   $externalDatabasePwd,
	[string]   $externalDatabaseServerCert,
	[switch]   $externalDatabaseSkipTls,

	[switch]   $skipToolOrchestration,

	[switch]   $useSaml,
	[string]   $samlAppName,
	[string]   $samlIdentityProviderMetadataPath,
	[string]   $samlKeystorePwd,
	[string]   $samlPrivateKeyPwd,

	[Tuple`2[string,string]] $codeDxNodeSelector,
	[Tuple`2[string,string]] $masterDatabaseNodeSelector,
	[Tuple`2[string,string]] $subordinateDatabaseNodeSelector,
	[Tuple`2[string,string]] $toolServiceNodeSelector,
	[Tuple`2[string,string]] $minioNodeSelector,
	[Tuple`2[string,string]] $workflowControllerNodeSelector,

	[Tuple`2[string,string]] $codeDxNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $masterDatabaseNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $subordinateDatabaseNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $toolServiceNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $minioNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $workflowControllerNoScheduleExecuteToleration,

	[switch] $pauseAfterGitClone,

	[management.automation.scriptBlock] $provisionNetworkPolicy,
	[management.automation.scriptBlock] $provisionIngressController
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'./common/helm.ps1','./common/codedx.ps1','./common/prereqs.ps1','./common/mariadb.ps1','./common/keytool.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Write-ImportantNote([string] $message) {
	Write-Host ('NOTE: {0}' -f $message) -ForegroundColor Black -BackgroundColor White
}

$prereqMessages = @()
if (-not (Test-SetupPreqs ([ref]$prereqMessages))) {
	write-error ([string]::join("`n", $prereqMessages))
}

if ($kubeContextName -ne '') {
	Set-KubectlContext $kubeContextName
	Write-Verbose "Using kubeconfig context entry named $(Get-KubectlContext)"
}

$dns1123SubdomainExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
if (-not $skipIngressEnabled -and -not (Test-IsValidParameterValue $codeDxDnsName $dns1123SubdomainExpr)) { 
	$codeDxDnsName = Read-HostText 'Enter Code Dx domain name (e.g., www.codedx.io)' -validationExpr $dns1123SubdomainExpr 
}

if (-not (Test-IsValidParameterValue $namespaceCodeDx $dns1123SubdomainExpr)) {
	$namespaceCodeDx = Read-HostText 'Enter the Code Dx namespace' -validationExpr $dns1123SubdomainExpr 
}

if (-not (Test-IsValidParameterValue $releaseNameCodeDx $dns1123SubdomainExpr)) {
	$releaseNameCodeDx = Read-HostText 'Enter the Code Dx release name' -validationExpr $dns1123SubdomainExpr 
}

if (-not $skipToolOrchestration) {
	if (-not (Test-IsValidParameterValue $namespaceToolOrchestration $dns1123SubdomainExpr)) {
		$namespaceToolOrchestration = Read-HostText 'Enter the Code Dx Tool Orchestration namespace' -validationExpr $dns1123SubdomainExpr 
	}
	
	if (-not (Test-IsValidParameterValue $releaseNameToolOrchestration $dns1123SubdomainExpr)) {
		$releaseNameToolOrchestration = Read-HostText 'Enter the Code Dx Tool Orchestration release name' -validationExpr $dns1123SubdomainExpr 
	}
}

if (-not $skipTLS -and $clusterCertificateAuthorityCertPath -eq '') { 
	$clusterCertificateAuthorityCertPath = Read-Host -Prompt 'Enter path to cluster CA certificate' 
}

if (-not $skipToolOrchestration -and $minioAdminUsername -eq '') { 
	$minioAdminUsername = Read-HostSecureText 'Enter a username for the MinIO admin account' 5 
}

if (-not $skipToolOrchestration -and $minioAdminPwd -eq '') { 
	$minioAdminPwd = Get-MinioPasswordFromPd $namespaceToolOrchestration $releaseNameToolOrchestration
	if ('' -eq $minioAdminPwd) {
		$minioAdminPwd = Read-HostSecureText 'Enter a password for the MinIO admin account' 8 
	}
}

if ($codedxAdminPwd -eq '') { 
	$codeDxAdminPwd = Get-CodeDxAdminPwdFromPd $namespaceCodeDx $releaseNameCodeDx
	if ('' -eq $codeDxAdminPwd) {
		$codedxAdminPwd = Read-HostSecureText 'Enter a password for the Code Dx admin account' 8 
	}
}

if (-not $skipToolOrchestration -and $toolServiceApiKey -eq '') { 
	$toolServiceApiKey = Get-ToolServiceApiKeyFromPd $namespaceToolOrchestration $releaseNameToolOrchestration
	if ('' -eq $toolServiceApiKey) {
		$toolServiceApiKey = Read-HostSecureText 'Enter an API key for the Code Dx Tool Orchestration service' 8 
	}
}

if ($caCertsFilePwd -eq '') {
	$caCertsFilePwd = Get-CacertsPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
	if ($caCertsFilePwd -eq '') {
		$caCertsFilePwd = 'changeit'
	}
}

if ($caCertsFileNewPwd -eq '') {
	$caCertsFileNewPwd = Get-CacertsNewPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
}

if ($caCertsFileNewPwd -ne '' -and $caCertsFileNewPwd.length -lt 6) { 
	$caCertsFileNewPwd = Read-HostSecureText 'Enter a password to protect the cacerts file' 6 
}

if ($samlKeystorePwd -eq '') {
	$samlKeystorePwd = Get-SamlKeystorePasswordFromPd $namespaceCodeDx $releaseNameCodeDx
}

if ($samlPrivateKeyPwd -eq '') {
	$samlPrivateKeyPwd = Get-SamlPrivateKeyPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
}

$externalDatabaseUrl = ''
if ($skipDatabase) {

	if ($externalDatabaseHost -eq '') { $externalDatabaseHost = Read-HostText 'Enter your external database host name' }
	if ($externalDatabaseName -eq '') { $externalDatabaseName = Read-HostText 'Enter your external, preexisting Code Dx database name' }

	if ($externalDatabaseUser -eq '') { 
		$externalDatabaseUser = Get-ExternalDatabaseUserFromPd $namespaceCodeDx $releaseNameCodeDx
		if ('' -eq $externalDatabaseUser) {
			$externalDatabaseUser = Read-HostText 'Enter a username for your external Code Dx database' 
		}
	}

	if ($externalDatabasePwd -eq '')  {
		$externalDatabasePwd  = Get-ExternalDatabasePasswordFromPd $namespaceCodeDx $releaseNameCodeDx 
		if ('' -eq $externalDatabasePwd) {
			$externalDatabasePwd  = Read-HostSecureText 'Enter a password for your external Code Dx database' 
		}
	}

	if (-not $externalDatabaseSkipTls) {
		if ($externalDatabaseServerCert -eq '') { $externalDatabaseServerCert = Read-HostText 'Enter your external database host cert file path' }
		
		$extraCodeDxTrustedCaCertPaths += $externalDatabaseServerCert

		if ($caCertsFilePath -eq '') { 
			$caCertsFilePath = Read-HostText 'Enter a path to a cacerts file where your external database host cert will be stored'
		}
	}
	$externalDatabaseUrl = Get-DatabaseUrl $externalDatabaseHost $externalDatabasePort $externalDatabaseName $externalDatabaseServerCert -databaseSkipTls:$externalDatabaseSkipTls
}
else {

	if ($mariadbRootPwd -eq '') { 
		$mariadbRootPwd = Get-DatabaseRootPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		if ('' -eq $mariadbRootPwd) {
			$mariadbRootPwd = Read-HostSecureText 'Enter a password for the MariaDB root user' 
		}
	}
	if ($mariadbReplicatorPwd -eq '') { 
		$mariadbReplicatorPwd = Get-DatabaseReplicationPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		if ('' -eq $mariadbReplicatorPwd) {
			$mariadbReplicatorPwd = Read-HostSecureText 'Enter a password for the MariaDB replicator user' 
		}
	}
}

if (-not $skipLetsEncryptCertManagerInstall){

	if ($letsEncryptCertManagerRegistrationEmailAddress -eq '') { 
		$letsEncryptCertManagerRegistrationEmailAddress = Read-HostText 'Enter an email address for the Let''s Encrypt registration' 
	}
	if ($letsEncryptCertManagerClusterIssuer -eq '') { 
		$letsEncryptCertManagerClusterIssuer = Read-HostText 'Enter a cluster issuer name for Let''s Encrypt' 
	}
}

if ($dockerImagePullSecretName -ne '') {
	
	if ($dockerRegistry -eq '') {
		$dockerRegistry = Read-HostText 'Enter private Docker registry'
	}
	if ($dockerRegistryUser -eq '') {
		$dockerRegistryUser = Read-HostText "Enter a docker username for $dockerRegistry"
	}
	if ($dockerRegistryPwd -eq '') {
		$dockerRegistryPwd = Get-DockerRegistryPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		if ('' -eq $dockerRegistryPwd) {
			$dockerRegistryPwd = Read-HostSecureText "Enter a docker password for $dockerRegistry"
		}
	}
}

if (-not $skipTls -and -not (test-path $clusterCertificateAuthorityCertPath -PathType Leaf)) {
	write-error "Unable to continue because path '$clusterCertificateAuthorityCertPath' cannot be found."
}

if (-not $skipDatabase -and $dbSlaveReplicaCount -eq 0) {
	Write-ImportantNote 'Skipping slave database instances and the database backup process they provide.'
}

$workDir = join-path $workDir "$releaseNameCodeDx-$releaseNameToolOrchestration"
Write-Verbose "Creating directory $workDir..."
New-Item -Type Directory $workDir -Force

Write-Verbose "Switching to directory $workDir..."
Push-Location $workDir

$useNetworkPolicies = -not $skipNetworkPolicies
if ($useNetworkPolicies -and $null -ne $provisionNetworkPolicy) {
	Write-Verbose "Adding network policy provider..."
	& $provisionNetworkPolicy $waitTimeSeconds
}

Write-Verbose 'Waiting for running pods...'
$namespaceCodeDx,$nginxIngressControllerNamespace,$letsEncryptCertManagerNamespace | ForEach-Object {
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

if (-not $skipNginxIngressControllerInstall) {

	Write-Verbose 'Adding nginx Ingress...'
	$priorityValuesFile = 'nginx-ingress-priority.yaml'

	if ($nginxIngressControllerLoadBalancerIP -ne '') {
		Add-NginxIngressLoadBalancerIP $nginxIngressControllerLoadBalancerIP $nginxIngressControllerNamespace $waitTimeSeconds 'nginx-ingress.yaml' $priorityValuesFile $releaseNameCodeDx $nginxCPUReservation $nginxMemoryReservation $nginxEphemeralStorageReservation -enablePSPs:(-not $skipPSPs)
	} else {
		Add-NginxIngress $nginxIngressControllerNamespace $waitTimeSeconds '' $priorityValuesFile $releaseNameCodeDx $nginxCPUReservation $nginxMemoryReservation $nginxEphemeralStorageReservation
	}

	$ingressAnnotationsCodeDx['nginx.ingress.kubernetes.io/proxy-read-timeout'] = '3600'
	$ingressAnnotationsCodeDx['nginx.ingress.kubernetes.io/proxy-body-size'] = '0'
}

if (-not $skipLetsEncryptCertManagerInstall) {

	Write-Verbose 'Adding Let''s Encrypt Cert Manager...'
	Add-LetsEncryptCertManager $letsEncryptCertManagerNamespace $namespaceCodeDx `
		$letsEncryptCertManagerRegistrationEmailAddress 'staging-cluster-issuer.yaml' 'production-cluster-issuer.yaml' `
		'cert-manager-role.yaml' 'cert-manager-role-binding.yaml' 'cert-manager-http-solver-role-binding.yaml' `
		$waitTimeSeconds -enablePSPs:(-not $skipPSPs)

	$ingressAnnotationsCodeDx['kubernetes.io/tls-acme'] = 'true'
	$ingressAnnotationsCodeDx['cert-manager.io/cluster-issuer'] = $letsEncryptCertManagerClusterIssuer
}

New-CodeDxPdSecret $namespaceCodeDx $releaseNameCodeDx `
	$codedxAdminPwd `
	$caCertsFilePwd `
	$externalDatabaseUser $externalDatabasePwd `
	$dockerRegistryPwd `
	$caCertsFileNewPwd `
	$samlKeystorePwd `
	$samlPrivateKeyPwd

Write-Verbose 'Fetching Code Dx Helm charts...'
Remove-Item .\codedx-kubernetes -Force -Confirm:$false -Recurse -ErrorAction SilentlyContinue
Invoke-GitClone $codedxGitRepo $codedxGitRepoBranch
if ($pauseAfterGitClone) {
	Read-Host -Prompt 'git clone complete, press Enter to continue...' | Out-Null
}

if ($extraCodeDxChartFilesPaths.Count -gt 0) {
	$codeDxChartsDirectory = './codedx-kubernetes/setup/core/charts/codedx'
	Write-Verbose "Copying the following extra files to '$codeDxChartsDirectory':`n$extraCodeDxChartFilesPaths"
	Copy-Item -LiteralPath $extraCodeDxChartFilesPaths -Destination $codeDxChartsDirectory
}

if ($skipNginxIngressControllerInstall -and $null -eq $provisionIngressController) {
	$nginxIngressControllerNamespace = ''
}

$caCertPaths = $extraCodeDxTrustedCaCertPaths
if ((-not $skipTLS) -and -not $skipToolOrchestration) {
	$caCertPaths += $clusterCertificateAuthorityCertPath
}

$codeDxChartsFolder = join-path $workDir 'codedx-kubernetes/setup/core/charts/codedx'

$caCertsFilename = ''
$certificateWorkRemains = $true
if ($caCertsFilePath -ne '') {
	Write-Verbose 'Configuring cacerts file...'
	New-TrustedCaCertsFile $caCertsFilePath $caCertsFilePwd $caCertsFileNewPwd $caCertPaths $codeDxChartsFolder

	$caCertsFilename = 'cacerts'
	$certificateWorkRemains = $false
}

$installToolOrchestration = -not $skipToolOrchestration

Write-Verbose 'Deploying Code Dx with Tool Orchestration disabled...'
New-CodeDxDeployment $codeDxDnsName $codeDxServicePortNumber $codeDxTlsServicePortNumber $workDir $waitTimeSeconds `
	$clusterCertificateAuthorityCertPath `
	$namespaceCodeDx $releaseNameCodeDx $imageCodeDxTomcat `
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
	$nginxIngressControllerNamespace `
	$ingressAnnotationsCodeDx `
	$caCertsFilename `
	$externalDatabaseUrl `
	$samlAppName $samlIdentityProviderMetadataPath `
	$codeDxNodeSelector $masterDatabaseNodeSelector $subordinateDatabaseNodeSelector `
	$codeDxNoScheduleExecuteToleration $masterDatabaseNoScheduleExecuteToleration $subordinateDatabaseNoScheduleExecuteToleration `
	-useSaml:$useSaml `
	-ingressEnabled:(-not $skipIngressEnabled) -ingressAssumesNginx:(-not $skipIngressAssumesNginx) `
	-enablePSPs:(-not $skipPSPs) -enableNetworkPolicies:$useNetworkPolicies -configureTls:(-not $skipTLS) -skipDatabase:$skipDatabase `
	-offlineMode:($certificateWorkRemains -or $installToolOrchestration)

if ($caCertsFilePath -eq '') {
	$caCertsFilePath = './cacerts.pod'
	Get-RunningCodeDxKeystore $namespaceCodeDx $caCertsFilePath
}

if ($certificateWorkRemains) {

	Write-Verbose 'Configuring cacerts file...'
	New-TrustedCaCertsFile $caCertsFilePath $caCertsFilePwd $caCertsFileNewPwd $caCertPaths $codeDxChartsFolder

	Set-TrustedCerts $workDir `
		$waitTimeSeconds `
		$namespaceCodeDx `
		$releaseNameCodeDx `
		$extraCodeDxValuesPaths `
		-offlineMode:$installToolOrchestration
}

if ($installToolOrchestration) {

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
		$toolServiceNodeSelector $minioNodeSelector $workflowControllerNodeSelector `
		$toolServiceNoScheduleExecuteToleration $minioNoScheduleExecuteToleration $workflowControllerNoScheduleExecuteToleration `
		-enablePSPs:(-not $skipPSPs) -enableNetworkPolicies:$useNetworkPolicies -configureTls:(-not $skipTLS)

	Write-Verbose 'Updating Code Dx deployment by enabling Tool Orchestration...'
	$protocol = 'http'
	if (-not $skipTLS) {
		$protocol = 'https'
	}

	$toolOrchestrationFullName = Get-CodeDxToolOrchestrationChartFullName $releaseNameToolOrchestration
	Set-UseToolOrchestration $workDir `
		$waitTimeSeconds `
		$clusterCertificateAuthorityCertPath `
		$namespaceToolOrchestration $namespaceCodeDx `
		"$protocol`://$toolOrchestrationFullName.$namespaceToolOrchestration.svc.cluster.local:3333" $toolServiceApiKey `
		$releaseNameCodeDx `
		$extraCodeDxValuesPaths `
		-enableNetworkPolicies:$useNetworkPolicies
}

Write-Verbose 'Done'
Write-ImportantNote "The '$workDir' directory may contain .key files and other configuration data that should be kept private."
