<#PSScriptInfo
.VERSION 2.8.0
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
	[string]                 $workDir = "$HOME/.k8s-codedx",
	[string]                 $kubeContextName,

	[string]                 $clusterCertificateAuthorityCertPath,
	[string]                 $codeDxDnsName,
	[int]                    $codeDxServicePortNumber = 9090,
	[int]                    $codeDxTlsServicePortNumber = 9443,
	[int]                    $waitTimeSeconds = 900,

	[int]                    $dbVolumeSizeGiB = 32,
	[int]                    $dbSlaveReplicaCount = 1,
	[int]                    $dbSlaveVolumeSizeGiB = 32,
	[int]                    $minioVolumeSizeGiB = 32,
	[int]                    $codeDxVolumeSizeGiB = 32,

	[string]                 $storageClassName,
	[string]                 $codeDxAppDataStorageClassName,
	[string]                 $dbStorageClassName,
	[string]                 $minioStorageClassName,

	[string]                 $codeDxMemoryReservation,
	[string]                 $dbMasterMemoryReservation,
	[string]                 $dbSlaveMemoryReservation,
	[string]                 $toolServiceMemoryReservation,
	[string]                 $minioMemoryReservation,
	[string]                 $workflowMemoryReservation,

	[string]                 $codeDxCPUReservation,
	[string]                 $dbMasterCPUReservation,
	[string]                 $dbSlaveCPUReservation,
	[string]                 $toolServiceCPUReservation,
	[string]                 $minioCPUReservation,
	[string]                 $workflowCPUReservation,

	[string]                 $codeDxEphemeralStorageReservation = '2Gi',
	[string]                 $dbMasterEphemeralStorageReservation,
	[string]                 $dbSlaveEphemeralStorageReservation,
	[string]                 $toolServiceEphemeralStorageReservation,
	[string]                 $minioEphemeralStorageReservation,
	[string]                 $workflowEphemeralStorageReservation,

	[string]                 $imageCodeDxTomcat       = 'codedx/codedx-tomcat:v2023.1.3',
	[string]                 $imageCodeDxTools        = 'codedx/codedx-tools:v2023.1.3',
	[string]                 $imageCodeDxToolsMono    = 'codedx/codedx-toolsmono:v2023.1.3',

	[string]                 $imagePrepare            = 'codedx/codedx-prepare:v1.20.0',
	[string]                 $imageNewAnalysis        = 'codedx/codedx-newanalysis:v1.20.0',
	[string]                 $imageSendResults        = 'codedx/codedx-results:v1.20.0',
	[string]                 $imageSendErrorResults   = 'codedx/codedx-error-results:v1.20.0',
	[string]                 $imageToolService        = 'codedx/codedx-tool-service:v1.20.0',
	[string]                 $imagePreDelete          = 'codedx/codedx-cleanup:v1.20.0',

	[string]                 $imageCodeDxTomcatInit   = 'codedx/codedx-tomcat:v2023.1.3',
	[string]                 $imageMariaDB            = 'codedx/codedx-mariadb:v1.19.0',
	[string]                 $imageMinio              = 'bitnami/minio:2021.4.6-debian-10-r11',
	[string]                 $imageWorkflowController = 'codedx/codedx-workflow-controller:v2.16.0',
	[string]                 $imageWorkflowExecutor   = 'codedx/codedx-argoexec:v2.16.0',

	[int]                    $toolServiceReplicas = 3,

	[switch]                 $skipTLS,
	[switch]                 $skipServiceTLS,
	[string]                 $csrSignerNameCodeDx            = 'kubernetes.io/legacy-unknown',
	[string]                 $csrSignerNameToolOrchestration = 'kubernetes.io/legacy-unknown',

	[switch]                 $skipPSPs,
	[switch]                 $skipNetworkPolicies,

	[int]                    $proxyPort,
	[int[]]                  $egressPortsTCP = @(22,7990,7999),
	[int[]]                  $egressPortsUDP,

	[string]                 $serviceTypeCodeDx,
	[hashtable]              $serviceAnnotationsCodeDx = @{},

	[switch]                 $skipIngressEnabled,
	[string]                 $ingressClassNameCodeDx = 'nginx',
	[string]                 $ingressTlsSecretNameCodeDx = 'ingress-tls-secret',
	[hashtable]              $ingressAnnotationsCodeDx = @{},

	[string]                 $namespaceToolOrchestration = 'cdx-svc',
	[string]                 $namespaceCodeDx = 'cdx-app',
	[string]                 $releaseNameCodeDx = 'codedx',
	[string]                 $releaseNameToolOrchestration = 'codedx-tool-orchestration',

	[string]                 $toolServiceApiKey,

	[string]                 $codedxAdminPwd,
	[string]                 $minioAdminUsername = 'admin',
	[string]                 $minioAdminPwd,
	[string]                 $mariadbRootPwd,
	[string]                 $mariadbReplicatorPwd,

	[switch]                 $skipUseRootDatabaseUser,
	[string]                 $codedxDatabaseUserPwd,

	[string]                 $caCertsFilePath,
	[string]                 $caCertsFilePwd,
	[string]                 $caCertsFileNewPwd,
	
	[string[]]               $extraCodeDxTrustedCaCertPaths = @(),

	[string]                 $dockerImagePullSecretName,
	[string]                 $dockerRegistry,
	[string]                 $dockerRegistryUser,
	[string]                 $dockerRegistryPwd,
	
	[string]                 $redirectDockerHubReferencesTo,

	[string]                 $codedxHelmRepo = 'https://codedx.github.io/codedx-kubernetes',
	
	[string]                 $codedxGitRepo = 'https://github.com/codedx/codedx-kubernetes.git',
	[string]                 $codedxGitRepoBranch = 'charts-2.27.0',

	[int]                    $kubeApiTargetPort = 443,

	[string[]]               $extraCodeDxValuesPaths = @(),
	[string[]]               $extraToolOrchestrationValuesPath = @(),

	[switch]                 $skipDatabase,
	[string]                 $externalDatabaseHost,
	[int]                    $externalDatabasePort = 3306,
	[string]                 $externalDatabaseName,
	[string]                 $externalDatabaseUser,
	[string]                 $externalDatabasePwd,
	[string]                 $externalDatabaseServerCert,
	[switch]                 $externalDatabaseSkipTls,

	[switch]                 $skipToolOrchestration,

	[switch]                 $useSaml,
	[string]                 $samlAppName,
	[string]                 $samlIdentityProviderMetadataPath,
	[string]                 $samlKeystorePwd,
	[string]                 $samlPrivateKeyPwd,

	[Tuple`2[string,string]] $codeDxNodeSelector,
	[Tuple`2[string,string]] $masterDatabaseNodeSelector,
	[Tuple`2[string,string]] $subordinateDatabaseNodeSelector,
	[Tuple`2[string,string]] $toolServiceNodeSelector,
	[Tuple`2[string,string]] $minioNodeSelector,
	[Tuple`2[string,string]] $workflowControllerNodeSelector,
	[Tuple`2[string,string]] $toolNodeSelector,

	[Tuple`2[string,string]] $codeDxNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $masterDatabaseNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $subordinateDatabaseNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $toolServiceNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $minioNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $workflowControllerNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $toolNoScheduleExecuteToleration,

	[switch]                 $pauseAfterGitClone,

	[switch]                 $useHelmOperator,
	[switch]                 $useHelmController,
	[switch]                 $useHelmManifest,
	[switch]                 $useHelmCommand,
	[switch]                 $skipSealedSecrets,
	[string]                 $sealedSecretsNamespace,
	[string]                 $sealedSecretsControllerName,
	[string]                 $sealedSecretsPublicKeyPath,

	[string]                 $backupType,
	[string]                 $namespaceVelero = 'velero',
	[string]                 $backupScheduleCronExpression = '0 3 * * *',
	[int]                    $backupDatabaseTimeoutMinutes = 30,
	[int]                    $backupTimeToLiveHours = 720,

	[int]                    $workflowStepMinimumRunTimeSeconds = 3,
	[switch]                 $createSCCs,

	[int]                    $connectionPoolEffectiveSpindleCount,
	[int]                    $connectionPoolTimeoutMilliseconds = 30000,
	[int]                    $concurrentAnalysisLimit,
	[int]                    $jobsLimitCpu,
	[int]                    $jobsLimitMemory,
	[int]                    $jobsLimitDatabase,
	[int]                    $jobsLimitDisk
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

# Use "Legacy" argument passing to avoid errors from conditional empty string arguments
$global:PSNativeCommandArgumentPassing='Legacy'

'../../.install-guided-setup-module.ps1','./common/codedx.ps1','./common/prereqs.ps1','./common/mariadb.ps1','./common/velero.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-ErrorMessageAndExit "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Get-DockerImageName([string] $dockerRegistryRedirect, [string] $imageName) {

	if ('' -eq $imageName -or '' -eq $dockerRegistryRedirect) {
		return $imageName
	}

	$imageNameParts = Get-DockerImageParts $imageName
	if ($imageNameParts[0] -ne 'docker.io') {
		return $imageName
	}

	if ($imageNameParts[1] -notmatch '^codedx/codedx-.+' -and $imageNameParts[1] -ne 'bitnami/minio') {
		return $imageName
	}

	return "$dockerRegistryRedirect/$($imageNameParts[1]):$($imageNameParts[2])"
}

$useTLS = -not $skipTLS
$useServiceTLS = -not $skipServiceTLS
$usePSPs = -not $skipPSPs
$useToolOrchestration = -not $skipToolOrchestration
$useNetworkPolicies = -not $skipNetworkPolicies
$useIngress = -not $skipIngressEnabled
$useLocalDatabase = -not $skipDatabase
$useRootDatabaseUser = -not $skipUseRootDatabaseUser

$useGitOps = $useHelmOperator -or $useHelmController -or $useHelmManifest -or $useHelmCommand
$useSealedSecrets = $useGitOps -and -not $skipSealedSecrets

$useVelero = $backupType -like 'velero*'


### Check Prerequisites
Write-Verbose 'Checking prerequisites...'
$prereqMessages = @()
if (-not (Test-SetupPreqs ([ref]$prereqMessages) -useSealedSecrets:$useSealedSecrets $kubeContextName -checkKubectlVersion)) {
	Write-ErrorMessageAndExit ([string]::join("`n", $prereqMessages))
}

$csrSignerNameLegacyUnknown = Get-CsrSignerNameLegacyUnknown
$isBetaCsrRequired = $csrSignerNameCodeDx -eq $csrSignerNameLegacyUnknown -or $csrSignerNameToolOrchestration -eq $csrSignerNameLegacyUnknown
if (-not $skipTLS -and $isBetaCsrRequired -and -not (Test-CertificateSigningRequestV1Beta1)) {
	# the v1 stable CSR API no longer supports the legacy-unknown signer name
	Write-ErrorMessageAndExit "Unable to continue because you previously enabled the TLS deployment option with the 'kubernetes.io/legacy-unknown' signer name. That signer requires the v1beta1 version of the Certificate Request Signer (CSR) resource, unavailable in this Kubernetes version. You must either disable the TLS deployment option by using the -skipTLS deployment script parameter or switch to an alternate Certificate Request Signer. For an example of enabling the TLS deployment option with cert-manager (https://cert-manager.io/docs/usage/kube-csr/), refer to https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/config/cert-manager-csr-upgrade.md."
}

### Validate Parameters
if ($useToolOrchestration -and $workflowStepMinimumRunTimeSeconds -le 0) {
	Write-ErrorMessageAndExit "Using the PNS executor requires workflow steps to run for a minimum amount of time. The value for -workflowStepMinimumRunTimeSeconds ($workflowStepMinimumRunTimeSeconds), which must be greater than 0."
}

$dns1123SubdomainExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
if ($useIngress -and -not (Test-IsValidParameterValue $codeDxDnsName $dns1123SubdomainExpr)) { 
	$codeDxDnsName = Read-HostText 'Enter Code Dx domain name (e.g., www.codedx.io)' -validationExpr $dns1123SubdomainExpr 
}

if (-not (Test-IsValidParameterValue $namespaceCodeDx $dns1123SubdomainExpr)) {
	$namespaceCodeDx = Read-HostText 'Enter the Code Dx namespace' -validationExpr $dns1123SubdomainExpr 
}

if (-not (Test-IsValidParameterValue $releaseNameCodeDx $dns1123SubdomainExpr)) {
	$releaseNameCodeDx = Read-HostText 'Enter the Code Dx release name' -validationExpr $dns1123SubdomainExpr 
}

if ($useToolOrchestration) {
	if (-not (Test-IsValidParameterValue $namespaceToolOrchestration $dns1123SubdomainExpr)) {
		$namespaceToolOrchestration = Read-HostText 'Enter the Code Dx Tool Orchestration namespace' -validationExpr $dns1123SubdomainExpr 
	}
	
	if (-not (Test-IsValidParameterValue $releaseNameToolOrchestration $dns1123SubdomainExpr)) {
		$releaseNameToolOrchestration = Read-HostText 'Enter the Code Dx Tool Orchestration release name' -validationExpr $dns1123SubdomainExpr 
	}
}

if ($useTLS -and $clusterCertificateAuthorityCertPath -eq '') { 
	$clusterCertificateAuthorityCertPath = Read-Host -Prompt 'Enter path to cluster CA certificate' 
}

if ($useToolOrchestration -and $minioAdminUsername -eq '') { 
	$minioAdminUsername = Read-HostSecureText 'Enter a username for the MinIO admin account' 5 
}

if ($useToolOrchestration -and $minioAdminPwd -eq '') { 
	if (-not $useGitOps) {
		$minioAdminPwd = Get-MinioPasswordFromPd $namespaceToolOrchestration $releaseNameToolOrchestration
	}
	if ('' -eq $minioAdminPwd) {
		$minioAdminPwd = Read-HostSecureText 'Enter a password for the MinIO admin account' 8 
	}
}

if ($codedxAdminPwd -eq '') { 
	if (-not $useGitOps) {
		$codeDxAdminPwd = Get-CodeDxAdminPwdFromPd $namespaceCodeDx $releaseNameCodeDx
	}
	if ('' -eq $codeDxAdminPwd) {
		$codedxAdminPwd = Read-HostSecureText 'Enter a password for the Code Dx admin account' 8 
	}
}

if ($useToolOrchestration -and $toolServiceApiKey -eq '') { 
	if (-not $useGitOps) {
		$toolServiceApiKey = Get-ToolServiceApiKeyFromPd $namespaceToolOrchestration $releaseNameToolOrchestration
	}
	if ('' -eq $toolServiceApiKey) {
		$toolServiceApiKey = Read-HostSecureText 'Enter an API key for the Code Dx Tool Orchestration service' 8 
	}
}

if ($caCertsFilePwd -eq '') {
	if (-not $useGitOps) {
		$caCertsFilePwd = Get-CacertsPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
	}
	if ($caCertsFilePwd -eq '') {
		$caCertsFilePwd = 'changeit'
	}
}

if ($caCertsFileNewPwd -eq '') {
	if (-not $useGitOps) {
		$caCertsFileNewPwd = Get-CacertsNewPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
	}

	if ($caCertsFileNewPwd -eq '') {
		$caCertsFileNewPwd = $cacertsFilePwd
	}
}

$invalidCacertPasswordCharacters = @("'")
if ($caCertsFileNewPwd -ne '' -and (($caCertsFileNewPwd.length -lt 6) -or (Test-IsBlacklisted $caCertsFileNewPwd $invalidCacertPasswordCharacters))) { 
	$caCertsFileNewPwd = Read-HostSecureText 'Enter a password to protect the cacerts file' 6 -blacklist $invalidCacertPasswordCharacters
}

if ($samlKeystorePwd -eq '') {
	if (-not $useGitOps) {
		$samlKeystorePwd = Get-SamlKeystorePasswordFromPd $namespaceCodeDx $releaseNameCodeDx
	}
}

if ($samlPrivateKeyPwd -eq '') {
	if (-not $useGitOps) {
		$samlPrivateKeyPwd = Get-SamlPrivateKeyPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
	}
}

$externalDatabaseUrl = ''
if ($skipDatabase) {

	if ($externalDatabaseHost -eq '') { $externalDatabaseHost = Read-HostText 'Enter your external database host name' }
	if ($externalDatabaseName -eq '') { $externalDatabaseName = Read-HostText 'Enter your external, preexisting Code Dx database name' }

	if ($externalDatabaseUser -eq '') { 
		if (-not $useGitOps) {
			$externalDatabaseUser = Get-ExternalDatabaseUserFromPd $namespaceCodeDx $releaseNameCodeDx
		}
		if ('' -eq $externalDatabaseUser) {
			$externalDatabaseUser = Read-HostText 'Enter a username for your external Code Dx database' 
		}
	}

	if ($externalDatabasePwd -eq '')  {
		if (-not $useGitOps) {
			$externalDatabasePwd  = Get-ExternalDatabasePasswordFromPd $namespaceCodeDx $releaseNameCodeDx 
		}
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

	$mariadbRootPwdPrompt = 'Enter a password for the MariaDB root user'
	$mariadbReplicatorPwdPrompt = 'Enter a password for the MariaDB replicator user'
	$invalidMariaDbPasswordCharacters = @("'")

	if ($mariadbRootPwd -eq '') { 
		if (-not $useGitOps) {
			$mariadbRootPwd = Get-DatabaseRootPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		}
		if ('' -eq $mariadbRootPwd) {
			$mariadbRootPwd = Read-HostSecureText $mariadbRootPwdPrompt -blacklist $invalidMariaDbPasswordCharacters
		}
	}
	if ($mariadbReplicatorPwd -eq '') { 
		if (-not $useGitOps) {
			$mariadbReplicatorPwd = Get-DatabaseReplicationPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		}
		if ('' -eq $mariadbReplicatorPwd) {
			$mariadbReplicatorPwd = Read-HostSecureText $mariadbReplicatorPwdPrompt -blacklist $invalidMariaDbPasswordCharacters
		}
	}

	if (Test-IsBlacklisted $mariadbRootPwd $invalidMariaDbPasswordCharacters) {
		$mariadbRootPwd = Read-HostSecureText $mariadbRootPwdPrompt -blacklist $invalidMariaDbPasswordCharacters
	}
	if (Test-IsBlacklisted $mariadbReplicatorPwd $invalidMariaDbPasswordCharacters) {
		$mariadbReplicatorPwd = Read-HostSecureText $mariadbReplicatorPwdPrompt -blacklist $invalidMariaDbPasswordCharacters
	}

	if ($skipUseRootDatabaseUser -and $codedxDatabaseUserPwd -eq '') {
		if (-not $useGitOps) {
			$codedxDatabaseUserPwd = Get-DatabaseUserDbPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		}
		if ('' -eq $codedxDatabaseUserPwd) {
			$codedxDatabaseUserPwd = Read-HostSecureText 'Enter a password for the MariaDB codedx database user'
		}
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
		if (-not $useGitOps) {
			$dockerRegistryPwd = Get-DockerRegistryPasswordFromPd $namespaceCodeDx $releaseNameCodeDx
		}
		if ('' -eq $dockerRegistryPwd) {
			$dockerRegistryPwd = Read-HostSecureText "Enter a docker password for $dockerRegistry"
		}
	}
}

if ('' -ne $redirectDockerHubReferencesTo) {

	$imageCodeDxTomcat       = Get-DockerImageName $redirectDockerHubReferencesTo $imageCodeDxTomcat
	$imageCodeDxTools        = Get-DockerImageName $redirectDockerHubReferencesTo $imageCodeDxTools
	$imageCodeDxToolsMono    = Get-DockerImageName $redirectDockerHubReferencesTo $imageCodeDxToolsMono
	$imagePrepare            = Get-DockerImageName $redirectDockerHubReferencesTo $imagePrepare
	$imageNewAnalysis        = Get-DockerImageName $redirectDockerHubReferencesTo $imageNewAnalysis
	$imageSendResults        = Get-DockerImageName $redirectDockerHubReferencesTo $imageSendResults
	$imageSendErrorResults   = Get-DockerImageName $redirectDockerHubReferencesTo $imageSendErrorResults
	$imageToolService        = Get-DockerImageName $redirectDockerHubReferencesTo $imageToolService
	$imagePreDelete          = Get-DockerImageName $redirectDockerHubReferencesTo $imagePreDelete
	$imageCodeDxTomcatInit   = Get-DockerImageName $redirectDockerHubReferencesTo $imageCodeDxTomcatInit
	$imageMariaDB            = Get-DockerImageName $redirectDockerHubReferencesTo $imageMariaDB
	$imageMinio              = Get-DockerImageName $redirectDockerHubReferencesTo $imageMinio
	$imageWorkflowController = Get-DockerImageName $redirectDockerHubReferencesTo $imageWorkflowController
	$imageWorkflowExecutor   = Get-DockerImageName $redirectDockerHubReferencesTo $imageWorkflowExecutor
}

$tlsFiles = @()

if ($useTLS -and -not (test-path $clusterCertificateAuthorityCertPath -PathType Leaf)) {
	Write-ErrorMessageAndExit "Unable to continue because path '$clusterCertificateAuthorityCertPath' cannot be found."
}

if ($useLocalDatabase -and $dbSlaveReplicaCount -eq 0) {
	Write-ImportantNote 'Skipping slave database instances and the database backup process they provide.'
}

if ($useGitOps -and $useSealedSecrets -and $sealedSecretsNamespace -eq '') { 
	$sealedSecretsNamespace = Read-Host -Prompt 'Enter the namespace containing the Sealed Secrets software (e.g., adm)'
}

if ($useGitOps -and $useSealedSecrets -and $sealedSecretsControllerName -eq '') { 
	$sealedSecretsControllerName = Read-Host -Prompt 'Enter the name of the Sealed Secrets controller (e.g., sealed-secrets)'
}

if ($useGitOps -and $useSealedSecrets -and $sealedSecretsPublicKeyPath -eq '') { 
	$sealedSecretsPublicKeyPath = Read-Host -Prompt 'Enter the path of the public key generated by the Sealed Secrets software'
}

$codeDxMustTrustCerts = -not (0 -eq $extraCodeDxTrustedCaCertPaths.Length -and '' -eq $clusterCertificateAuthorityCertPath)

if ('' -eq $caCertsFilePath -and $useGitOps -and $codeDxMustTrustCerts) {
	$caCertsFilePath = Read-HostText 'Enter a path to a cacerts file where your extra certificates or cluster CA cert will be stored'
}

if ($kubeContextName -eq '' -and $useGitOps) {
	$kubeContextName = Read-HostText 'Enter a kube context name (required for helm-operator)'
}

if ($backupType -eq '') {
	$backupType = 'none'
}

if ('none','velero','velero-restic' -notcontains $backupType) {
	Write-ErrorMessageAndExit "Unable to continue because backup type $backupType is unknown."
}

if ($useVelero) {
	if (-not (Test-IsValidParameterValue $namespaceVelero $dns1123SubdomainExpr)) {
		$namespaceVelero = Read-HostText 'Enter the Velero namespace' -validationExpr $dns1123SubdomainExpr 
	}

	if ($backupDatabaseTimeoutMinutes -le 0) {
		$backupDatabaseTimeoutMinutes = [int](Read-HostText 'Enter backup database timeout in minutes ' -validationExpr '^[1-9]\d*$' -validationHelp 'Enter the number of minutes (1 or more)')
	}

	if ($backupTimeToLiveHours -le 0) {
		$backupTimeToLiveHours = [int](Read-HostText 'Enter backup time to live in hours ' -validationExpr '^[1-9]\d*$' -validationHelp 'Enter the number of hours (1 or more)')
	}
}

$codeDxVirtualCpuCount = Get-VirtualCpuCountFromReservation $codeDxCPUReservation
if ($codeDxVirtualCpuCount -lt 2) {
	Write-ErrorMessageAndExit "Unable to continue because the Code Dx CPU reservation ($codeDxCPUReservation) is less than the minimum value (2 vCPUs, or 2000m)."
}

if ($storageClassName -ne '') {
	$codeDxAppDataStorageClassName = $codeDxAppDataStorageClassName -eq '' ? $storageClassName : $codeDxAppDataStorageClassName
	$dbStorageClassName            = $dbStorageClassName            -eq '' ? $storageClassName : $dbStorageClassName
	$minioStorageClassName         = $minioStorageClassName         -eq '' ? $storageClassName : $minioStorageClassName
}

if (0 -ne $proxyPort -and $egressPortsTCP -notcontains $proxyPort) {
	$egressPortsTCP += $proxyPort
}

### Select Kube Context
if ($kubeContextName -ne '') {
	Write-Verbose "Selecting kubectl context named $kubeContextName..."
	Set-KubectlContext $kubeContextName
	Write-Verbose "Using kubeconfig context entry named $(Get-KubectlContext)"
}

### Check whether this is an unsupported upgrade scenario
if ($useHelmManifest -and (Test-CodeDxDeployment $namespaceCodeDx)) {
	Write-ErrorMessageAndExit "Code Dx appears to be installed already in the $namespaceCodeDx namespace. When using the -useHelmManifest parameter, upgrades must be performed by rerunning the deployment script on a cluster where Code Dx does not exist and manually merging the resulting YAML with previously generated YAML."
}

### Create Work Directory
$workDir = join-path $workDir "$releaseNameCodeDx-$releaseNameToolOrchestration"
Write-Verbose "Creating directory $workDir..."
New-Item -Type Directory $workDir -Force

### Switch to Work Directory
Write-Verbose "Switching to directory $workDir..."
Push-Location $workDir

### Reset GitOps/Resources directory
$gitOpsDir = './Resources'
if (Test-Path $gitOpsDir -PathType Container) {
	Remove-Item $gitOpsDir -Force -Confirm:$false -Recurse -ErrorAction SilentlyContinue
}

### Fetch Code Dx Charts
Write-Verbose 'Fetching Code Dx Helm charts...'
$repoDirectory = './.repo'
$oldRepoDirectory = './codedx-kubernetes'
$repoDirectory,$oldRepoDirectory | ForEach-Object {
	if (Test-Path $_ -PathType Container) {
		Remove-Item $_ -Force -Confirm:$false -Recurse -ErrorAction SilentlyContinue
	}
}

Invoke-GitClone $codedxGitRepo $codedxGitRepoBranch $repoDirectory
if ($pauseAfterGitClone) {
	Read-Host -Prompt 'git clone complete, press Enter to continue...' | Out-Null
}

### Enforce Upgrade Constraint(s)
$codeDxChartPath = join-path $repoDirectory 'setup/core/charts/codedx'
$minimumCodeDxChartVersion = new-object Management.Automation.SemanticVersion('1.74.0')
if (Test-CodeDxChartUpgradeBlocked `
	$codeDxChartPath `
	$namespaceCodeDx `
	$releaseNameCodeDx `
	$minimumCodeDxChartVersion `
	-skipDatabase:$skipDatabase) {

	$minimumCodeDxK8sVersion = 'v2.19.0'
	$gitRoot = [IO.Path]::GetFullPath((join-path $PSScriptRoot '../..'))

	Write-Host @"
`nYou cannot upgrade directly to this Code Dx version. You must first upgrade to codedx-kubernetes $minimumCodeDxK8sVersion by doing the following:

1) cd $gitRoot`n
2) git checkout $minimumCodeDxK8sVersion`n
3) rerun your run-setup.ps1 to install version $minimumCodeDxK8sVersion`n
4) cd $gitRoot`n
5) git checkout master`n
6) rerun your run-setup.ps1 to finish your upgrade`n
"@
	exit 1
}

### Wait for Cluster Ready
if (-not $useGitOps) {

	Write-Verbose 'Waiting for running pods...'
	$namespaceCodeDx | ForEach-Object {
		if (Test-Namespace $_) {
			Wait-AllRunningPods "Cluster Ready (namespace $_)" $waitTimeSeconds $_	
		}
	}

	if ($useToolOrchestration) {
		if (Test-Namespace $namespaceToolOrchestration) {
			Wait-AllRunningPods "Cluster Ready (namespace $namespaceToolOrchestration)" $waitTimeSeconds $namespaceToolOrchestration
		}
	}
}

### Create Code Dx Namespace
Write-Verbose "Creating namespace $namespaceCodeDx..."
New-NamespaceResource $namespaceCodeDx ([Tuple]::Create('name', $namespaceCodeDx)) -useGitOps:$useGitOps

### Optionally Configure Docker Image Pull Secret
if ('' -ne $dockerImagePullSecretName) {
	New-DockerImagePullSecretResource $namespaceCodeDx $dockerImagePullSecretName $dockerRegistry $dockerRegistryUser $dockerRegistryPwd -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
}

### Optionally Fetch cacerts from Pod
if ('' -eq $caCertsFilePath -and $codeDxMustTrustCerts) {
	Write-Verbose "Starting $imageCodeDxTomcat pod in namespace $namespaceCodeDx to fetch cacerts file..."
	$caCertsFilePath = (Get-CodeDxKeystore $namespaceCodeDx $imageCodeDxTomcat $dockerImagePullSecretName $waitTimeSeconds './cacerts-from-pod').FullName
}

### Optionally Create Code Dx Tool Orchestration Namespace
if ($useToolOrchestration) {
	Write-Verbose "Creating namespace $namespaceToolOrchestration..."
	New-NamespaceResource $namespaceToolOrchestration ([Tuple]::Create('name', $namespaceToolOrchestration)) -useGitOps:$useGitOps
}

### Optionally Configure Code Dx TLS
$tlsSecretNameCodeDx = ''
$tlsSecretNameMasterDatabase = ''
$masterDatabaseCertConfigMapName = ''
$codeDxChartFullName = Get-CodeDxChartFullName $releaseNameCodeDx
if ($useTLS) {

	$tlsCertFile = "$codeDxChartFullName.pem"
	$tlsKeyFile = "$codeDxChartFullName.key"

	# NOTE: New-Certificate uses kubectl to create and approve a CertificateSigningRequest, so this next line requires cluster access
	$tlsFiles += $tlsCertFile
	New-Certificate $csrSignerNameCodeDx $clusterCertificateAuthorityCertPath $codeDxChartFullName $codeDxChartFullName $tlsCertFile $tlsKeyFile $namespaceCodeDx @()

	$tlsSecretNameCodeDx = "$codeDxChartFullName-tls"
	New-CertificateSecretResource $namespaceCodeDx $tlsSecretNameCodeDx $tlsCertFile $tlsKeyFile -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

	if ($useLocalDatabase) {
		
		$masterDatabaseServiceName = Get-MariaDbChartFullName $releaseNameCodeDx

		# NOTE: New-Certificate uses kubectl to create and approve a CertificateSigningRequest, so this next line requires cluster access
		$masterDatabaseCertFile = "$masterDatabaseServiceName.pem"
		$tlsFiles += $masterDatabaseCertFile
		New-Certificate $csrSignerNameCodeDx $clusterCertificateAuthorityCertPath $masterDatabaseServiceName $masterDatabaseServiceName $masterDatabaseCertFile "$masterDatabaseServiceName.key" $namespaceCodeDx @()

		$tlsSecretNameMasterDatabase = "$masterDatabaseServiceName-tls"
		New-CertificateSecretResource $namespaceCodeDx $tlsSecretNameMasterDatabase $masterDatabaseCertFile "$masterDatabaseServiceName.key" -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

		$masterDatabaseCertConfigMapName = "$masterDatabaseServiceName-ca-cert"
		New-CertificateConfigMapResource $namespaceCodeDx $masterDatabaseCertConfigMapName $clusterCertificateAuthorityCertPath 'ca.crt' -useGitOps:$useGitOps
	}
}

### Optionally Configure Code Dx Orchestration TLS
$tlsToolServiceCertSecretName = ''
$codedxCaConfigMapName = ''
$tlsMinioCertSecretName = ''
$minioCertConfigMapName = ''
$toolOrchestrationFullName = Get-CodeDxToolOrchestrationChartFullName $releaseNameToolOrchestration
if ($useTLS -and $useToolOrchestration) {

	$minioFullName = '{0}-minio' -f $releaseNameToolOrchestration
	
	# NOTE: New-Certificate uses kubectl to create and approve a CertificateSigningRequest, so it requires cluster access
	$minioPublicKeyFile = 'minio.pem'; $minioPrivateKeyFile = 'minio.key'
	$tlsFiles += $minioPublicKeyFile
	New-Certificate $csrSignerNameToolOrchestration $clusterCertificateAuthorityCertPath $minioFullName $minioFullName $minioPublicKeyFile $minioPrivateKeyFile $namespaceToolOrchestration @()

	$tlsMinioCertSecretName = '{0}-minio-tls' -f $toolOrchestrationFullName
	New-CertificateSecretResource $namespaceToolOrchestration $tlsMinioCertSecretName $minioPublicKeyFile $minioPrivateKeyFile -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

	$minioCertConfigMapName = '{0}-minio-cert' -f $toolOrchestrationFullName
	New-CertificateConfigMapResource $namespaceToolOrchestration $minioCertConfigMapName $minioPublicKeyFile -useGitOps:$useGitOps

	# NOTE: New-Certificate uses kubectl to create and approve a CertificateSigningRequest, so it requires cluster access
	$toolServicePublicKeyFile = 'toolsvc.pem'; $toolServicePrivateKeyFile = 'toolsvc.key'
	$tlsFiles += $toolServicePublicKeyFile
	New-Certificate $csrSignerNameToolOrchestration $clusterCertificateAuthorityCertPath $toolOrchestrationFullName $toolOrchestrationFullName $toolServicePublicKeyFile $toolServicePrivateKeyFile $namespaceToolOrchestration @()

	$tlsToolServiceCertSecretName = '{0}-tls' -f $toolOrchestrationFullName
	New-CertificateSecretResource $namespaceToolOrchestration $tlsToolServiceCertSecretName $toolServicePublicKeyFile $toolServicePrivateKeyFile -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

	$codedxCaConfigMapName = '{0}-ca-cert' -f $codeDxChartFullName
	New-CertificateConfigMapResource $namespaceToolOrchestration $codedxCaConfigMapName $clusterCertificateAuthorityCertPath -useGitOps:$useGitOps
}

Write-Verbose 'Adding Helm repository...'
Add-HelmRepo 'codedx' $codedxHelmRepo



### Optionally Deploy Code Dx Orchestration
if ($useToolOrchestration) {

	New-ToolServicePdSecret $namespaceToolOrchestration $releaseNameToolOrchestration $toolServiceApiKey -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
	New-MinioPdSecret $namespaceToolOrchestration $releaseNameToolOrchestration $minioAdminUsername $minioAdminPwd -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

	if ('' -ne $dockerImagePullSecretName) {
		New-DockerImagePullSecretResource $namespaceToolOrchestration $dockerImagePullSecretName $dockerRegistry $dockerRegistryUser $dockerRegistryPwd  -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
	}

	Write-Verbose 'Creating Tool Orchestration values file...'
	$toolOrchestrationValuesFile = New-ToolOrchestrationValuesFile `
		$namespaceCodeDx `
		$releaseNameCodeDx `
		$codeDxServicePortNumber $codeDxTlsServicePortNumber `
		$toolServiceReplicas `
		$imageCodeDxTools $imageCodeDxToolsMono `
		$imagePrepare $imageNewAnalysis $imageSendResults $imageSendErrorResults $imageToolService $imagePreDelete `
		$imageMinio $imageWorkflowController $imageWorkflowExecutor `
		$dockerImagePullSecretName `
		$minioVolumeSizeGiB $minioStorageClassName `
		$toolServiceMemoryReservation $minioMemoryReservation $workflowMemoryReservation `
		$toolServiceCPUReservation $minioCPUReservation $workflowCPUReservation `
		$toolServiceEphemeralStorageReservation $minioEphemeralStorageReservation $workflowEphemeralStorageReservation `
		$kubeApiTargetPort `
		(Get-ToolServicePdSecretName $releaseNameToolOrchestration) `
		(Get-MinioPdSecretName $releaseNameToolOrchestration) `
		$tlsToolServiceCertSecretName $codedxCaConfigMapName `
		$tlsMinioCertSecretName $minioCertConfigMapName `
		$toolServiceNodeSelector $minioNodeSelector $workflowControllerNodeSelector $toolNodeSelector `
		$toolServiceNoScheduleExecuteToleration $minioNoScheduleExecuteToleration $workflowControllerNoScheduleExecuteToleration $toolNoScheduleExecuteToleration `
		$backupType `
		-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS -configureServiceTls:$useServiceTLS `
		'./toolsvc-values.yaml' `
		-usePnsExecutor:$true `
		$workflowStepMinimumRunTimeSeconds `
		-createSCCs:$createSCCs

	Write-Verbose 'Creating CRDs...'
	$crdDirectory = (Test-CertificateSigningRequestV1Beta1) ? 'v1beta1' : 'v1'
	Get-ChildItem (join-path $repoDirectory 'setup/core/crds' $crdDirectory) -File | ForEach-Object {
		if ($useGitOps) {
			Write-Verbose "Creating resource file for $($_.Name) with $_..."
			New-ResourceFile 'CRD' $namespaceToolOrchestration $_.Name (Get-Content $_)
		} else {
			Write-Verbose "Deploying resource $($_.Name) with $_..."
			Set-K8sResource $_
		}
	}

	Write-Verbose 'Deploying Tool Orchestration...'
	$chartFolder = join-path $workDir .repo/setup/core/charts/codedx-tool-orchestration
	$helmResult = Invoke-HelmCommand 'Tool Orchestration' `
		$waitTimeSeconds $namespaceToolOrchestration `
		$releaseNameToolOrchestration `
		$chartFolder `
		$toolOrchestrationValuesFile.FullName `
		$extraToolOrchestrationValuesPath `
		-dryRun:$useGitOps `
		-skipCRDs

	if (-not $useGitOps) {
		Wait-Deployment 'Helm Upgrade/Install: Tool Orchestration' $waitTimeSeconds $namespaceToolOrchestration $toolOrchestrationFullName $toolServiceReplicas
	}

	if ($useHelmManifest) {
		New-ResourceFile 'HelmManifest' $namespaceToolOrchestration $releaseNameToolOrchestration $helmResult
	}
}

New-CodeDxPdSecret $namespaceCodeDx $releaseNameCodeDx $codedxAdminPwd $caCertsFilePwd $externalDatabaseUser $externalDatabasePwd $dockerRegistryPwd $caCertsFileNewPwd $samlKeystorePwd $samlPrivateKeyPwd -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
New-DatabasePdSecret $namespaceCodeDx $releaseNameCodeDx $mariadbRootPwd $mariadbReplicatorPwd $codedxDatabaseUserPwd -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

$dbConnectionSecret = 'codedx-mariadb-props'; $dbConnectionFile = './codedx.mariadb.props'

New-DatabaseConfigPropsFile `
	$namespaceCodeDx `
	$dbConnectionSecret `
	($externalDatabaseUser -eq '' ? ($useRootDatabaseUser ? 'root' : 'codedx') : $externalDatabaseUser) `
	($externalDatabasePwd  -eq '' ? ($useRootDatabaseUser ? $mariadbRootPwd : $codedxDatabaseUserPwd) : $externalDatabasePwd) `
	$dbConnectionFile
New-GenericSecretResource $namespaceCodeDx $dbConnectionSecret @{} @{'codedx.mariadb.props' = $dbConnectionFile} -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

### Optionally Add CA Certificate (required for TLS connection to database and Tool Service)
if ($useTLS) {
	$extraCodeDxTrustedCaCertPaths += $clusterCertificateAuthorityCertPath
}

### Optionally Configure Keystore File and Secret
$caCertsSecretName = ''
if ($caCertsFilePath -ne '') {
	Write-Verbose "Creating new cacerts file based on $caCertsFilePath..."
	New-TrustedCaCertsFile $caCertsFilePath $caCertsFilePwd $caCertsFileNewPwd $extraCodeDxTrustedCaCertPaths

	Write-Verbose 'Creating cacerts secret...'
	$caCertsFilename = 'cacerts'; $caCertsSecretName = $caCertsFilename
	New-GenericSecretResource $namespaceCodeDx $caCertsSecretName @{} @{$caCertsFilename=(join-path $workDir $caCertsFilename)} -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
}

### Optionally Configure SAML
$samlSecretName = ''
$samlIdpXmlFileConfigMapName = ''
if ($useSaml) {
	$samlIdpXmlFileConfigMapName = 'saml-idp'
	New-ConfigMapResource $namespaceCodeDx $samlIdpXmlFileConfigMapName @{} @{'saml-idp.xml' = $samlIdentityProviderMetadataPath} -useGitOps:$useGitOps

	$samlSecretName = 'codedx-saml-keystore-props'; $samlPropsFile = './codedx-saml-keystore.props'
	New-SamlConfigPropsFile $samlKeystorePwd $samlPrivateKeyPwd $samlPropsFile
	New-GenericSecretResource $namespaceCodeDx $samlSecretName @{} @{'codedx-saml-keystore.props' = $samlPropsFile} -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
}

### Optionally Configure Tool Service Connection
$toolServiceUrl = ''
$toolServiceApiKeySecretName = ''
if ($useToolOrchestration) {
	
	$toolServiceApiKeySecretName = 'codedx-orchestration-key-props'
	# Code Dx will read this data in Human-Optimized Config Object Notation (HOCON) format.
	New-GenericSecretResource $namespaceCodeDx $toolServiceApiKeySecretName @{$toolServiceApiKeySecretName = "tws.api-key = """"""$toolServiceApiKey"""""""} @{} -useGitOps:$useGitOps -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath

	$protocol = 'http'
	if ($useTLS) {
		$protocol = 'https'
	}
	$toolServiceUrl = "$protocol`://$(Get-CodeDxToolOrchestrationChartFullName $releaseNameToolOrchestration).$namespaceToolOrchestration.svc.cluster.local:3333"
}

if ($concurrentAnalysisLimit -eq 0) { $concurrentAnalysisLimit = $codeDxVirtualCpuCount }
if ($jobsLimitCpu -eq 0) { $jobsLimitCpu = 1000 * $codeDxVirtualCpuCount }
if ($jobsLimitMemory -eq 0) { $jobsLimitMemory = 1000 * $codeDxVirtualCpuCount }
if ($jobsLimitDatabase -eq 0) { $jobsLimitDatabase = 1000 * $codeDxVirtualCpuCount }
if ($jobsLimitDisk -eq 0) { $jobsLimitDisk = 1000 * $codeDxVirtualCpuCount }
if ($connectionPoolEffectiveSpindleCount -eq 0) { $connectionPoolEffectiveSpindleCount = 1 }

# https://github.com/brettwooldridge/HikariCP/wiki/About-Pool-Sizing#connections--core_count--2--effective_spindle_count
$connectionPoolMaxSize = $codeDxVirtualCpuCount * 2 + $connectionPoolEffectiveSpindleCount

### Create Code Dx Values File
Write-Verbose 'Creating Code Dx values file...'
$codeDxDeploymentValuesFile = New-CodeDxDeploymentValuesFile $codeDxDnsName $codeDxServicePortNumber $codeDxTlsServicePortNumber `
	$releaseNameCodeDx `
	$imageCodeDxTomcat $imageCodeDxTomcatInit $imageMariaDB `
	$dockerImagePullSecretName `
	$dbConnectionSecret `
	$dbVolumeSizeGiB `
	$dbSlaveReplicaCount $dbSlaveVolumeSizeGiB `
	$codeDxVolumeSizeGiB `
	$codeDxAppDataStorageClassName $dbStorageClassName `
	$codeDxMemoryReservation $dbMasterMemoryReservation $dbSlaveMemoryReservation `
	$codeDxCPUReservation $dbMasterCPUReservation $dbSlaveCPUReservation `
	$codeDxEphemeralStorageReservation $dbMasterEphemeralStorageReservation $dbSlaveEphemeralStorageReservation `
	$serviceTypeCodeDx $serviceAnnotationsCodeDx `
	$ingressClassNameCodeDx $ingressTlsSecretNameCodeDx $ingressAnnotationsCodeDx `
	$caCertsSecretName `
	$externalDatabaseUrl `
	$samlAppName $samlIdpXmlFileConfigMapName $samlSecretName `
	$tlsSecretNameCodeDx `
	$tlsSecretNameMasterDatabase $masterDatabaseCertConfigMapName `
	$codeDxNodeSelector $masterDatabaseNodeSelector $subordinateDatabaseNodeSelector `
	$codeDxNoScheduleExecuteToleration $masterDatabaseNoScheduleExecuteToleration $subordinateDatabaseNoScheduleExecuteToleration `
	$backupType `
	-useSaml:$useSaml `
	-ingressEnabled:$useIngress `
	-enablePSPs:$usePSPs -enableNetworkPolicies:$useNetworkPolicies -configureTls:$useTLS -configureServiceTls:$useServiceTLS -skipDatabase:$skipDatabase `
	-skipToolOrchestration:$skipToolOrchestration `
	$namespaceToolOrchestration `
	$toolServiceUrl `
	$toolServiceApiKeySecretName `
	-offlineMode:$false `
	'./codedx-values.yaml' `
	-createSCCs:$createSCCs `
	-useCodeDxDbUser:$skipUseRootDatabaseUser `
	$concurrentAnalysisLimit `
	$connectionPoolMaxSize $connectionPoolTimeoutMilliseconds `
	$jobsLimitCpu $jobsLimitMemory $jobsLimitDatabase $jobsLimitDisk `
	$egressPortsTCP $egressPortsUDP

### Deploy Code Dx
Write-Verbose 'Deploying Code Dx...'
$codeDxChartFolder = join-path $workDir .repo/setup/core/charts/codedx
$helmResult = Invoke-HelmCommand 'Code Dx' `
	$waitTimeSeconds $namespaceCodeDx `
	$releaseNameCodeDx `
	$codeDxChartFolder `
	$codeDxDeploymentValuesFile.FullName `
	$extraCodeDxValuesPaths `
	-dryRun:$useGitOps `
	-skipCRDs

if (-not $useGitOps) {
	Wait-Deployment 'Helm Upgrade/Install: Code Dx' $waitTimeSeconds $namespaceCodeDx $codeDxChartFullName 1
}

if ($useHelmManifest) {
	New-ResourceFile 'HelmManifest' $namespaceCodeDx $releaseNameCodeDx $helmResult
}

if ($useVelero) {

	$skipDatabaseBackup = $skipDatabase -or $dbSlaveReplicaCount -le 0

	$scheduleName = "$releaseNameCodeDx-schedule"
	$databaseBackupTimeout = "$($backupDatabaseTimeoutMinutes)m"
	$databaseBackupTimeToLive = "$($backupTimeToLiveHours)h0m0s"

	Write-Verbose "Creating Velero Schedule resource $scheduleName..."
	$schedule = New-VeleroBackupSchedule $workDir $scheduleName `
		'schedule.yaml' `
		$releaseNameCodeDx `
		$namespaceVelero `
		$backupScheduleCronExpression `
		$namespaceCodeDx `
		$namespaceToolOrchestration `
		$databaseBackupTimeout `
		$databaseBackupTimeToLive `
		-skipDatabaseBackup:$skipDatabaseBackup `
		-skipToolOrchestration:$skipToolOrchestration `
		-dryRun:$useGitOps

	if ($useGitOps) {
		New-ResourceFile 'Schedule' $namespaceVelero $scheduleName $schedule
	}
}

if ($useGitOps -and (-not $useHelmManifest)) {

	$useHelmRelease = $useHelmController -or $useHelmOperator

	### Create Code Dx HelmRelease
	$codeDxValuesPaths = @()
	$codeDxValuesConfigMapNames = @()
	$codeDxSetupValuesName = 'codedx-setup-values'

	if ($useHelmRelease) {
		New-ConfigMapResource $namespaceCodeDx $codeDxSetupValuesName @{} @{'values.yaml' = $codeDxDeploymentValuesFile.FullName} -useGitOps
		$codeDxValuesConfigMapNames += $codeDxSetupValuesName
	} else {
		$codeDxValuesPaths += $codeDxDeploymentValuesFile.FullName
	}

	$codeDxFileNumber = 0
	$codeDxUserValuesNameTemplate = 'codedx-user-values-{0}'
	$extraCodeDxValuesPaths | ForEach-Object {

		$codeDxUserValuesName = $codeDxUserValuesNameTemplate -f $codeDxFileNumber

		if ($useHelmRelease) {
			New-ConfigMapResource $namespaceCodeDx $codeDxUserValuesName @{} @{'values.yaml' = $_} -useGitOps
			$codeDxValuesConfigMapNames += $codeDxUserValuesName
		} else {
			$codeDxValuesPaths += $_
		}
		
		$codeDxFileNumber++
	}

	$codeDxDockerImageNames = @{
		'codedxTomcatImage' = $imageCodeDxTomcat;
		'codedxTomcatInitImage' = $imageCodeDxTomcatInit
	}

	$codeDxHelmReleaseName = 'codedx'
	if ($useHelmRelease) {
		New-HelmRelease $codeDxHelmReleaseName `
			$namespaceCodeDx `
			$releaseNameCodeDx `
			-chartGitName 'codedx-kubernetes' `
			-chartGit ($useHelmController ? 'https://github.com/codedx/codedx-kubernetes' : 'git@github.com:codedx/codedx-kubernetes') `
			-chartRef $codedxGitRepoBranch `
			-chartPath 'setup/core/charts/codedx' `
			-valuesConfigMapNames $codeDxValuesConfigMapNames `
			-dockerImageNames $codeDxDockerImageNames `
			-useHelmController:$useHelmController
	} else {
		New-HelmCommand $namespaceCodeDx `
			$releaseNameCodeDx `
			(join-path $workDir .repo/setup/core/charts/codedx) `
			$codeDxValuesPaths `
			$codeDxDockerImageNames
	}

	### Optionally Create Tool Orchestration HelmRelease
	if ($useToolOrchestration) {

		$toolOrchestrationValuesPaths = @()
		$toolOrchestrationValuesConfigMapNames = @()

		$toolOrchestrationSetupValuesName = 'codedx-tool-orchestration-setup-values'

		if ($useHelmRelease) {
			New-ConfigMapResource $namespaceToolOrchestration $toolOrchestrationSetupValuesName @{} @{'values.yaml' = $toolOrchestrationValuesFile.FullName} -useGitOps
			$toolOrchestrationValuesConfigMapNames += $toolOrchestrationSetupValuesName
		} else {
			$toolOrchestrationValuesPaths += $toolOrchestrationValuesFile.FullName
		}

		$toolOrchestrationFileNumber = 0
		$toolOrchestrationUserValuesNameTemplate = 'codedx-tool-orchestration-user-values-{0}'
		$extraToolOrchestrationValuesPath | ForEach-Object {
			$toolOrchestrationUserValuesName = $toolOrchestrationUserValuesNameTemplate -f $toolOrchestrationFileNumber

			if ($useHelmRelease) {
				New-ConfigMapResource $namespaceToolOrchestration $toolOrchestrationUserValuesName @{} @{'values.yaml' = $_} -useGitOps
				$toolOrchestrationValuesConfigMapNames += $toolOrchestrationUserValuesName
			} else {
				$toolOrchestrationValuesPaths += $_
			}
			
			$toolOrchestrationFileNumber++
		}

		$toolOrchestrationDockerImages = @{
			'imageNameCodeDxTools'      = $imageCodeDxTools;
			'imageNameCodeDxToolsMono'  = $imageCodeDxToolsMono;
			'imageNamePrepare'          = $imagePrepare;
			'imageNameNewAnalysis'      = $imageNewAnalysis;
			'imageNameSendResults'      = $imageSendResults;
			'imageNameSendErrorResults' = $imageSendErrorResults;
			'imageNameHelmPreDelete'    = $imagePreDelete;
			'toolServiceImageName'      = $imageToolService;
		}

		$toolOrchestrationHelmReleaseName = 'codedx-tool-orchestration'
		if ($useHelmRelease) {

			New-HelmRelease $toolOrchestrationHelmReleaseName `
				$namespaceToolOrchestration `
				$releaseNameToolOrchestration `
				-chartGitName 'codedx-kubernetes' `
				-chartGit ($useHelmController ? 'https://github.com/codedx/codedx-kubernetes' : 'git@github.com:codedx/codedx-kubernetes') `
				-chartRef $codedxGitRepoBranch `
				-chartPath 'setup/core/charts/codedx-tool-orchestration' `
				-valuesConfigMapNames $toolOrchestrationValuesConfigMapNames `
				-dockerImageNames $toolOrchestrationDockerImages `
				-useHelmController:$useHelmController
		} else {
			New-HelmCommand $namespaceToolOrchestration `
				$releaseNameToolOrchestration `
				(join-path $workDir .repo/setup/core/charts/codedx-tool-orchestration) `
				$toolOrchestrationValuesPaths `
				$toolOrchestrationDockerImages
		}
	}
}

Write-Verbose 'Done'

if ($tlsFiles.Count -gt 0) {

	Write-Host "`nIMPORTANT CERTIFICATE NOTES:"

	$date = Get-Content $clusterCertificateAuthorityCertPath | openssl x509 -enddate -noout
	Write-Host "`nCA certificate expiration (-clusterCertificateAuthorityCertPath parameter): $date"

	Write-Host "`nThis script generated the following certificates. You must rerun this script to generate new certificates and restart related components before the listed expiration times.`n"
	$tlsFiles | ForEach-Object {
		$certSubject = Get-Content $_ | openssl x509 -subject -noout
		$certEndDate = Get-Content $_ | openssl x509 -enddate -noout
		Write-Host "---`n$certSubject`n$certEndDate`n"
	}
}

Write-ImportantNote "The '$workDir' directory may contain .key files and other configuration data that should be kept private."
