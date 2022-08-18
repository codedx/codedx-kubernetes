
enum ProviderType {
	Minikube
	Aks
	Eks
	OpenShift
	Other
}

enum IngressType {
	ClusterIP
	NodePort
	LoadBalancer
	NginxIngress
	NginxExternalSecretIngress
	NginxCertManagerIngress
	ClassicElb
	NetworkElb
	InternalClassicElb
}

enum IssuerType {
	ClusterIssuer
	Issuer
}

class ConfigInput {

	static [int]   $codeDxTlsServicePortNumberDefault = 9443
	static [int]   $volumeSizeGiBDefault = 32
	static [int]   $toolServiceReplicasDefault = 3
	static [int]   $kubeApiTargetPortDefault = 443
	static [int]   $externalDatabasePortDefault = 3306

	static [string] $legacyUnknownSignerName = 'kubernetes.io/legacy-unknown'

	[bool]         $prereqsSatisified
	[string[]]     $missingPrereqs

	[string]       $workDir
	[ProviderType] $k8sProvider
	[string]       $kubeApiTargetPort
	[string]       $kubeContextName

	[int]          $codeDxTlsServicePortNumber

	[string]       $codeDxDnsName

	[string]       $namespaceCodeDx
	[string]       $releaseNameCodeDx
	[string]       $namespaceToolOrchestration
	[string]       $releaseNameToolOrchestration

	[string]       $storageClassName

	[bool]         $useVolumeSizeDefaults
	[int]          $codeDxVolumeSizeGiB
	[int]          $dbVolumeSizeGiB
	[int]          $dbSlaveVolumeSizeGiB
	[int]          $minioVolumeSizeGiB

	[bool]         $useCPUDefaults
	[string]       $codeDxCPUReservation
	[string]       $dbMasterCPUReservation
	[string]       $dbSlaveCPUReservation
	[string]       $toolServiceCPUReservation
	[string]       $minioCPUReservation
	[string]       $workflowCPUReservation

	[bool]         $useMemoryDefaults
	[string]       $codeDxMemoryReservation
	[string]       $dbMasterMemoryReservation
	[string]       $dbSlaveMemoryReservation
	[string]       $toolServiceMemoryReservation
	[string]       $minioMemoryReservation
	[string]       $workflowMemoryReservation

	[bool]         $useEphemeralStorageDefaults
	[string]       $codeDxEphemeralStorageReservation
	[string]       $dbMasterEphemeralStorageReservation
	[string]       $dbSlaveEphemeralStorageReservation
	[string]       $toolServiceEphemeralStorageReservation
	[string]       $minioEphemeralStorageReservation
	[string]       $workflowEphemeralStorageReservation

	[bool]         $useDefaultDockerImages
	[string]       $imageCodeDxTomcat
	[string]       $imageCodeDxTools
	[string]       $imageCodeDxToolsMono
	[string]       $imageToolService
	[string]       $imageSendResults
	[string]       $imageSendErrorResults
	[string]       $imageNewAnalysis
	[string]       $imagePrepare
	[string]       $imagePreDelete

	[string]       $imageCodeDxTomcatInit
	[string]       $imageMariaDB
	[string]       $imageMinio
	[string]       $imageWorkflowController
	[string]       $imageWorkflowExecutor

	[bool]         $useDockerRedirection
	[string]       $redirectDockerHubReferencesTo

	[int]          $toolServiceReplicas

	[bool]         $useDefaultOptions
	[bool]         $skipPSPs
	[bool]         $skipNetworkPolicies

	[bool]         $skipTLS
	[bool]         $skipServiceTLS
	[string]       $csrSignerNameCodeDx
	[string]       $csrSignerNameToolOrchestration

	[bool]         $useTriageAssistant

	[string]       $serviceTypeCodeDx
	[hashtable]    $serviceAnnotationsCodeDx

	[IngressType]  $ingressType

	[bool]         $skipIngressEnabled
	[string]       $ingressTlsSecretNameCodeDx
	[hashtable]    $ingressAnnotationsCodeDx

	[IssuerType]   $certManagerIssuerType

	[string]       $toolServiceApiKey
      
	[string]       $codedxAdminPwd
	[string]       $minioAdminPwd
	[string]       $mariadbRootPwd
	[string]       $mariadbReplicatorPwd
	[int]          $dbSlaveReplicaCount

	[string]       $codedxDatabaseUserPwd
	[bool]         $skipUseRootDatabaseUser
      
	[bool]         $skipToolOrchestration

	[bool]         $skipPrivateDockerRegistry
	[string]       $dockerImagePullSecretName
	[string]       $dockerRegistry
	[string]       $dockerRegistryUser
	[string]       $dockerRegistryPwd

	[bool]         $skipDatabase
	[string]       $externalDatabaseHost
	[int]          $externalDatabasePort
	[string]       $externalDatabaseName
	[string]       $externalDatabaseUser
	[string]       $externalDatabasePwd
	[bool]         $externalDatabaseSkipTls
	[string]       $externalDatabaseServerCert

	[bool]         $useDefaultCACerts
	[string]       $caCertsFilePath
	[string]       $caCertsFilePwd
	[bool]         $useNewCACertsFilePwd
	[string]       $caCertsFileNewPwd
	[bool]         $addExtraCertificates
	[string[]]     $extraCodeDxTrustedCaCertPaths

	[string]       $clusterCertificateAuthorityCertPath

	[bool]                   $useNodeSelectors
	[Tuple`2[string,string]] $codeDxNodeSelector
	[Tuple`2[string,string]] $masterDatabaseNodeSelector
	[Tuple`2[string,string]] $subordinateDatabaseNodeSelector
	[Tuple`2[string,string]] $toolServiceNodeSelector
	[Tuple`2[string,string]] $minioNodeSelector
	[Tuple`2[string,string]] $workflowControllerNodeSelector
	[Tuple`2[string,string]] $toolNodeSelector

	[bool]                   $useTolerations
	[Tuple`2[string,string]] $codeDxNoScheduleExecuteToleration
	[Tuple`2[string,string]] $masterDatabaseNoScheduleExecuteToleration
	[Tuple`2[string,string]] $subordinateDatabaseNoScheduleExecuteToleration
	[Tuple`2[string,string]] $toolServiceNoScheduleExecuteToleration
	[Tuple`2[string,string]] $minioNoScheduleExecuteToleration
	[Tuple`2[string,string]] $workflowControllerNoScheduleExecuteToleration
	[Tuple`2[string,string]] $toolNoScheduleExecuteToleration

	[string] $hostBasePath
	[bool]   $useSaml
	[string] $samlIdentityProviderMetadataPath
	[string] $samlAppName
	[string] $samlKeystorePwd
	[string] $samlPrivateKeyPwd
	[bool]   $useLdap

	[bool]   $useHelmOperator
	[bool]   $useHelmController
	[bool]   $useHelmManifest
	[bool]   $useHelmCommand
	[bool]   $skipSealedSecrets
	[string] $sealedSecretsNamespace
	[string] $sealedSecretsControllerName
	[string] $sealedSecretsPublicKeyPath

	[string] $backupType
	[string] $namespaceVelero
	[string] $backupScheduleCronExpression
	[int]    $backupDatabaseTimeoutMinutes
	[int]    $backupTimeToLiveHours

	[bool]   $createSCCs

	[hashtable]  $notes = @{}

	ConfigInput() {
		$this.codeDxTlsServicePortNumber = [ConfigInput]::codeDxTlsServicePortNumberDefault
		$this.codeDxVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
		$this.dbVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
		$this.dbSlaveVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
		$this.minioVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
		$this.toolServiceReplicas = [ConfigInput]::toolServiceReplicasDefault
		$this.kubeApiTargetPort = [ConfigInput]::kubeApiTargetPortDefault
		$this.externalDatabasePort = [ConfigInput]::externalDatabasePortDefault
		$this.certManagerIssuerType = [IssuerType]::ClusterIssuer
	}

	[bool]HasContext() {
		return $this.kubeContextName -ne ''
	}

	[bool]IsUsingVelero() {
		return $this.backupType -like 'velero*'
	}

	[bool]UseGitOps() {
		return $this.useHelmOperator -or $this.useHelmController -or $this.useHelmManifest -or $this.useHelmCommand
	}

	[bool]IsElbIngress() {
		return $this.ingressType -eq [IngressType]::ClassicElb -or `
			$this.ingressType -eq [IngressType]::NetworkElb -or `
			$this.ingressType -eq [IngressType]::InternalClassicElb
	}

	[bool]IsElbInternalIngress() {
		return $this.ingressType -eq [IngressType]::InternalClassicElb
	}

	[bool]IsNGINXIngress() {
		return $this.ingressType -eq [IngressType]::NginxIngress -or `
			$this.ingressType -eq [IngressType]::NginxCertManagerIngress -or `
			$this.ingressType -eq [IngressType]::NginxExternalSecretIngress
	}
}

class Step : GuidedSetupStep {

	[ConfigInput] $config

	Step([string]      $name, 
		 [ConfigInput] $config,
		 [string]      $title,
		 [string]      $message,
		 [string]      $prompt) : base($name, $title, $message, $prompt) {

		$this.config = $config
	}
}


