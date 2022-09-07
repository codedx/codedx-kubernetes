using module @{ModuleName='guided-setup'; RequiredVersion='1.7.0' }

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$location = join-path $PSScriptRoot '..'
push-location ($location)

'./test/mock.ps1',
'./test/pass.ps1',
'./setup/core/common/codedx.ps1',
'./setup/core/common/prereqs.ps1',
'./setup/steps/step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $location $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

$DebugPreference = 'Continue'

function Test-SetupParameters([string] $testScriptPath, [string] $runSetupPath, [string] $workDir, [string] $params) {

	$scriptPath = join-path (split-path $testScriptPath) 'setup/steps/../core/setup.ps1'
	$scriptCommand = '{0} -workDir ''{1}'' {2}' -f $scriptPath,$workDir,$params
	$actualCommand = Get-Content $runSetupPath
	$result = $actualCommand -eq $scriptCommand
	if (-not $result) {
		Write-Debug "`nExpected:`n$scriptCommand`nActual:`n$actualCommand"
	}
	$result
}

function Set-TestDefaults() {
	$global:kubeContexts = 'minikube','EKS','AKS','Other','OpenShift'
	$global:prereqsSatisified = $false
	$global:k8sport = 8443
	$global:caCertCertificateExists = $true
	$global:caCertFileExists = $true
	$global:keystorePasswordValid = $true
	$global:csrSupportsV1Beta1 = $true
}

Describe 'Generate Setup Command from Default Pass' -Tag 'DefaultPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(01) Should generate run-setup.ps1' {
	
		Set-DefaultPass

		New-Mocks
		. ./guided-setup.ps1
		
		join-path $TestDrive run-setup.ps1 | Should -Exist
	}

	It '(03) Should generate minikube setup.ps1 command without tool orchestration' {
	
		Set-DefaultPass

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Use Tool Orchestration and Subordinate Database Pass' -Tag 'UseToolOrchestrationAndSubordinateDatabasePass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(04) Should generate minikube setup.ps1 command with tool orchestration and subordinate database' {
	
		Set-UseToolOrchestrationAndSubordinateDatabasePass 1

		New-Mocks
		. ./guided-setup.ps1

	   $runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
	   $expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
	   Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
   }
}

Describe 'Generate Setup Command from External Database Pass' -Tag 'ExternalDatabasePass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(05) Should generate minikube setup.ps1 command with external database' {
	
		Set-ExternalDatabasePass 1

		New-Mocks
		. ./guided-setup.ps1

	   	$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
	   	$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
   }

   It '(06) Should generate minikube setup.ps1 command with external database and defaults' {

		Set-ExternalDatabasePass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic Load Balancer Ingress Pass' -Tag 'ClassicLoadBalancerIngressPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(07) Should generate EKS setup.ps1 command with AWS Classic Load Balancer' {
	
		Set-ClassicLoadBalancerIngressPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Node Selector and Pod Tolerations Pass' -Tag 'NodeSelectorAndPodTolerationsPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(08) Should generate EKS setup.ps1 command with node selectors and pod tolerations' {
	
		Set-NodeSelectorAndPodTolerationsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -codeDxNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes')) -codeDxNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','codedx-web')) -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -masterDatabaseNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes')) -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from All Node Selector and Pod Tolerations Pass' -Tag 'AllNodeSelectorAndPodTolerationsPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(09) Should generate EKS setup.ps1 command with all node selectors and pod tolerations' {
	
		Set-AllNodeSelectorAndPodTolerationsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -codeDxNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-1')) -codeDxNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','codedx-web')) -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -subordinateDatabaseNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-3')) -subordinateDatabaseNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','subordinate-db')) -masterDatabaseNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-2')) -masterDatabaseNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','master-db')) -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-4')) -toolServiceNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','tool-service')) -minioNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-5')) -minioNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','minio')) -workflowControllerNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-6')) -workflowControllerNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','workflow-controller')) -toolNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-7')) -toolNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','tools')) -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Recommended Resources Pass' -Tag 'RecommendedResourcesPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(10) Should generate EKS setup.ps1 command with recommended resources' {
	
		Set-RecommendedResourcesPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Docker Image Names and Private Registry Pass' -Tag 'DockerImageNamesAndPrivateRegistryPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(11) Should generate minikube setup.ps1 command with Docker image names and private registry' {
	
		Set-DockerImageNamesAndPrivateRegistryPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTools 'codedx-tools' -imageCodeDxToolsMono 'codedx-toolsmono' -imageNewAnalysis 'codedx-newanalysis' -imageSendResults 'codedx-sendresults' -imageSendErrorResults 'codedx-senderrorresults' -imageToolService 'codedx-toolservice' -imagePrepare 'codedx-prepare' -imagePreDelete 'codedx-cleanup' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMariaDB 'codedx-mariadb' -imageMinio 'minio' -imageWorkflowController 'codedx-workflow-controller' -imageWorkflowExecutor 'codedx-workflow-executor' -dockerImagePullSecretName 'private-reg' -dockerRegistry 'private-reg-host' -dockerRegistryUser 'private-reg-username' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -dockerRegistryPwd 'private-reg-password' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Config Certs Pass' -Tag 'ConfigCertsPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(12) Should generate minikube setup.ps1 command with custom cacerts file and extra certificates' {
	
		Set-ConfigCertsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -caCertsFileNewPwd 'changed' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -extraCodeDxTrustedCaCertPaths @('extra1.pem','extra2.pem')"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Use Custom Resources Pass' -Tag 'UseCustomResourcesPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(13) Should generate minikube setup.ps1 command with custom resources' {
	
		Set-UseCustomResourcesPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '501Mi' -dbMasterMemoryReservation '502Mi' -dbSlaveMemoryReservation '503Mi' -toolServiceMemoryReservation '504Mi' -minioMemoryReservation '505Mi' -workflowMemoryReservation '506Mi' -codeDxCPUReservation '1001m' -dbMasterCPUReservation '1002m' -dbSlaveCPUReservation '1003m' -toolServiceCPUReservation '1004m' -minioCPUReservation '1005m' -workflowCPUReservation '1006m' -codeDxEphemeralStorageReservation '1025Mi' -dbMasterEphemeralStorageReservation '1026Mi' -dbSlaveEphemeralStorageReservation '1027Mi' -toolServiceEphemeralStorageReservation '1028Mi' -minioEphemeralStorageReservation '1029Mi' -workflowEphemeralStorageReservation '1030Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 20 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 25 -dbSlaveVolumeSizeGiB 30 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 35 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Use Saml Pass' -Tag 'UseSamlPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(14) Should generate minikube setup.ps1 command with SAML configuration' {
	
		Set-UseSamlPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'codedx.com' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -useSaml -skipUseRootDatabaseUser -samlIdentityProviderMetadataPath 'idp-metadata.xml' -samlAppName 'codedxclient' -samlKeystorePwd 'my-keystore-password' -samlPrivateKeyPwd 'my-private-key-password' -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Some Docker Image Names' -Tag 'SomeDockerImageNames' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(15) Should generate minikube setup.ps1 command with some Docker image names' {
	
		Set-SomeDockerImageNames 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxToolsMono 'codedx-toolsmono' -imageNewAnalysis 'codedx-newanalysis' -imageSendResults 'codedx-sendresults' -imageSendErrorResults 'codedx-senderrorresults' -imageToolService 'codedx-toolservice' -imagePrepare 'codedx-prepare' -imagePreDelete 'codedx-cleanup' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMariaDB 'codedx-mariadb' -imageMinio 'minio' -imageWorkflowController 'codedx-workflow-controller' -imageWorkflowExecutor 'codedx-workflow-executor' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Pass With Default Resource Reservations' -Tag 'PassWithDefaultResourceReservations' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(16) Should generate minikube setup.ps1 command with default reservations' {
	
		Set-PassWithDefaultResourceReservations 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Pass With Custom Accepting Default Resource Reservations' -Tag 'PassWithCustomAcceptingDefaultResourceReservations' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(17) Should generate minikube setup.ps1 command with custom, accepting default, reservations' {
	
		Set-PassWithCustomAcceptingDefaultResourceReservations 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic Load Balancer Ingress GitOps Pass' -Tag 'ClassicLoadBalancerIngressGitOpsPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(18) Should generate EKS, GitOps setup.ps1 command with AWS Classic Load Balancer' {
	
		Set-ClassicLoadBalancerIngressGitOpsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmOperator -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic Load Balancer Ingress GitOps No TLS Pass' -Tag 'ClassicLoadBalancerIngressGitOpsNoTLSPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(19) Should generate EKS, GitOps setup.ps1 command with AWS Classic Load Balancer and no TLS' {
	
		Set-ClassicLoadBalancerIngressGitOpsNoTLSPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -useHelmOperator -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='http';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Default Pass With Velero' -Tag 'DefaultPassWithVelero' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(20) Should generate run-setup.ps1 with Velero plug-in backup type' {
	
		Set-DefaultPassWithVelero 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -backupType 'velero' -namespaceVelero 'velerons' -backupScheduleCronExpression '0 4 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 32 -backupTimeToLiveHours 24 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Default Pass With Velero Restic' -Tag 'DefaultPassWithVeleroRestic' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(21) Should generate run-setup.ps1 with Velero Restic integration backup type' {
	
		Set-DefaultPassWithVeleroRestic 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from OpenShift Pass' -Tag 'OpenShiftPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(22) Should generate run-setup.ps1 with OpenShift switches' {
	
		Set-OpenShiftPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'OpenShift' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -createSCCs -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from LoadBalancer Ingress Pass' -Tag 'LoadBalancerIngressPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(23) Should generate run-setup.ps1 for Classic ELB with TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$true -useTls:$true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(24) Should generate run-setup.ps1 for Classic ELB without TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$true -useTls:$false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='http';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(25) Should generate run-setup.ps1 for Network ELB with TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$false -useTls:$true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='ssl';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https';'service.beta.kubernetes.io/aws-load-balancer-type'='nlb'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(26) Should generate run-setup.ps1 for Network ELB without TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$false -useTls:$false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='http';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https';'service.beta.kubernetes.io/aws-load-balancer-type'='nlb'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Docker Image Names Database No Orchestration' -Tag 'DockerImageNamesDatabaseNoOrchestration' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(27) Should generate minikube setup.ps1 command with Docker image names and no orchestration' {
	
		Set-DockerImageNamesDatabaseNoOrchestration 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -codeDxEphemeralStorageReservation '2048Mi' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMariaDB 'codedx-mariadb' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(28) Should generate minikube setup.ps1 command with Docker image names and no database and no orchestration' {
	
		Set-DockerImageNamesNoDatabaseNoOrchestration 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTomcatInit 'codedx-tomcat-init' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(29) Should generate minikube setup.ps1 command with Docker image names and no database and orchestration' {
	
		Set-DockerImageNamesNoDatabaseOrchestration 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTools 'codedx-tools' -imageCodeDxToolsMono 'codedx-toolsmono' -imageNewAnalysis 'codedx-newanalysis' -imageSendResults 'codedx-sendresults' -imageSendErrorResults 'codedx-senderrorresults' -imageToolService 'codedx-toolservice' -imagePrepare 'codedx-prepare' -imagePreDelete 'codedx-cleanup' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMinio 'minio' -imageWorkflowController 'codedx-workflow-controller' -imageWorkflowExecutor 'codedx-workflow-executor' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Docker Image Redirect' -Tag 'DockerImageRedirect' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(30) Should generate minikube setup.ps1 command with anonymous redirect' {
	
		Set-DockerImageRedirect 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -codeDxEphemeralStorageReservation '2048Mi' -redirectDockerHubReferencesTo 'myregistry.codedx.com' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Docker Image Private Redirect' -Tag 'DockerImagePrivateRedirect' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(31) Should generate minikube setup.ps1 command with private registry redirect' {
	
		Set-DockerImagePrivateRedirect 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -codeDxEphemeralStorageReservation '2048Mi' -dockerImagePullSecretName 'private-reg' -dockerRegistry 'private-reg-host' -dockerRegistryUser 'private-reg-username' -redirectDockerHubReferencesTo 'private-reg-host' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -dockerRegistryPwd 'private-reg-password' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Requires Pns Pass' -Tag 'RequiresPnsPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(32) Should generate setup.ps1 command with PNS' {
	
		Set-RequiresPnsPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'Other' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Requires Other Docker Pass' -Tag 'OtherDockerPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(33) Should generate setup.ps1 command without PNS' {
	
		Set-OtherDockerPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'Other' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic Load Balancer Ingress GitOps Toolkit Pass' -Tag 'ClassicLoadBalancerIngressGitOpsToolkitPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(34) Should generate EKS, GitOps Toolkit setup.ps1 command with AWS Classic Load Balancer' {
	
		Set-ClassicLoadBalancerIngressGitOpsToolkitPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmController -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic LoadBalancer Internal Ingress Pass' -Tag 'ClassicLoadBalancerInternalIngressPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(35) Should generate EKS setup.ps1 command with AWS Internal Classic Load Balancer' {
	
		Set-ClassicLoadBalancerInternalIngressPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-internal'='true';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic LoadBalancer Ingress Helm Manifest Pass' -Tag 'ClassicLoadBalancerIngressHelmManifestPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(36) Should generate Helm manifest setup.ps1 command with AWS Classic Load Balancer' {
	
		Set-ClassicLoadBalancerIngressHelmManifestPass

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmManifest -skipSealedSecrets -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic LoadBalancer Ingress Helm Manifest With Sealed Secrets Pass' -Tag 'ClassicLoadBalancerIngressHelmManifestWithSealedSecretsPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(37) Should generate Helm manifest setup.ps1 command with Sealed Secrets and AWS Classic Load Balancer' {
	
		Set-ClassicLoadBalancerIngressHelmManifestWithSealedSecretsPass

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmManifest -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Use CertManager ClusterIssuer No Tool Orchestration' -Tag 'UseCertManagerClusterIssuerNoToolOrchestration' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(38) Should use cert-manager ClusterIssuer signer without Tool Orchestration' {
	
		Set-UseCertManagerClusterIssuerNoToolOrchestration 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Use CSR CertManager ClusterIssuer' -Tag 'UseCertManagerCSRClusterIssuer' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(39) Should use cert-manager ClusterIssuer signer' {
	
		Set-UseCertManagerClusterIssuer 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer' -csrSignerNameToolOrchestration 'clusterissuers.cert-manager.io/ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Use CertManager CSR Issuers' -Tag 'UseCertManagerCSRIssuers' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(40) Should use cert-manager Issuer signers' {
	
		Set-UseCertManagerIssuers 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'issuers.cert-manager.io/cdx-app.ca-issuer' -csrSignerNameToolOrchestration 'issuers.cert-manager.io/cdx-svc.ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Must Use CertManager ClusterIssuer No Tool Orchestration' -Tag 'MustUseCertManagerClusterIssuerNoToolOrchestration' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(41) Should use cert-manager ClusterIssuer signer because legacy-unknown is unsupported without tool orchestration' {
	
		Set-MustUseCertManagerClusterIssuerNoToolOrchestration 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Must Use CertManager ClusterIssuer' -Tag 'MustUseCertManagerClusterIssuer' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(42) Should use cert-manager Issuer signers because legacy-unknown is unsupported' {
	
		Set-MustUseCertManagerClusterIssuer 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'issuers.cert-manager.io/cdx-app.ca-issuer' -csrSignerNameToolOrchestration 'issuers.cert-manager.io/cdx-svc.ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Triage Assistant Pass' -Tag 'TriageAssistantPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(43) Should increase CPU and memory for Triage Assistant' {
	
		Set-TriageAssistantPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '16384Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '4000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from NodePort Ingress Pass' -Tag 'NodePortIngressPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(44) Should generate setup command for NodePort ingress' {
	
		Set-NodePortIngressPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'NodePort' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from HTTPS NGINX cert-manager Ingress Pass' -Tag 'NGINXCertManagerIngressPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(45) Should generate setup command with cert-manager Issuer NGINX ingress and TLS Code Dx service' {
	
		Set-NGINXCertManagerIngressPass 1 $true $false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'www.codedx.io' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -ingressAnnotationsCodeDx @{'cert-manager.io/issuer'='cert-manager-issuer';'nginx.ingress.kubernetes.io/backend-protocol'='HTTPS';'nginx.ingress.kubernetes.io/proxy-body-size'='0';'nginx.ingress.kubernetes.io/proxy-read-timeout'='3600'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(46) Should generate setup command with cert-manager Issuer NGINX ingress and no TLS Code Dx service' {
	
		Set-NGINXCertManagerIngressPass 1 $false $false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'www.codedx.io' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipServiceTLS -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -ingressAnnotationsCodeDx @{'cert-manager.io/issuer'='cert-manager-issuer';'nginx.ingress.kubernetes.io/backend-protocol'='HTTP';'nginx.ingress.kubernetes.io/proxy-body-size'='0';'nginx.ingress.kubernetes.io/proxy-read-timeout'='3600'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(47) Should generate setup command with cert-manager ClusterIssuer NGINX ingress and TLS Code Dx service' {
	
		Set-NGINXCertManagerIngressPass 1 $true $true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'www.codedx.io' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -ingressAnnotationsCodeDx @{'cert-manager.io/cluster-issuer'='cert-manager-issuer';'nginx.ingress.kubernetes.io/backend-protocol'='HTTPS';'nginx.ingress.kubernetes.io/proxy-body-size'='0';'nginx.ingress.kubernetes.io/proxy-read-timeout'='3600'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(48) Should generate setup command with cert-manager ClusterIssuer NGINX ingress and no TLS Code Dx service' {
	
		Set-NGINXCertManagerIngressPass 1 $false $true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'www.codedx.io' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipServiceTLS -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -ingressAnnotationsCodeDx @{'cert-manager.io/cluster-issuer'='cert-manager-issuer';'nginx.ingress.kubernetes.io/backend-protocol'='HTTP';'nginx.ingress.kubernetes.io/proxy-body-size'='0';'nginx.ingress.kubernetes.io/proxy-read-timeout'='3600'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}	
}

Describe 'Generate Setup Command from IngressWithTLSPass' -Tag 'NGINXTLSIngressPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(49) Should generate setup command with NGINX Lets Encrypt ingress and TLS Code Dx service' {
	
		Set-NGINXTLSIngressPass 1 $true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'www.codedx.io' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -ingressTlsSecretNameCodeDx 'kubernetes-tls-secret-name' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -ingressAnnotationsCodeDx @{'nginx.ingress.kubernetes.io/backend-protocol'='HTTPS';'nginx.ingress.kubernetes.io/proxy-body-size'='0';'nginx.ingress.kubernetes.io/proxy-read-timeout'='3600'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(50) Should generate setup command with NGINX Lets Encrypt ingress and no TLS Code Dx service' {
	
		Set-NGINXTLSIngressPass 1 $false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'www.codedx.io' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'ClusterIP' -ingressTlsSecretNameCodeDx 'kubernetes-tls-secret-name' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipServiceTLS -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -ingressAnnotationsCodeDx @{'nginx.ingress.kubernetes.io/backend-protocol'='HTTP';'nginx.ingress.kubernetes.io/proxy-body-size'='0';'nginx.ingress.kubernetes.io/proxy-read-timeout'='3600'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}

Describe 'Generate Setup Command from Classic Load Balancer Ingress HelmCommand Pass' -Tag 'ClassicLoadBalancerIngressHelmCommandPass' {

	BeforeEach {
		Set-TestDefaults
	}

	It '(51) Should generate EKS, HelmCommand setup.ps1 command with AWS Classic Load Balancer' {
	
		Set-ClassicLoadBalancerIngressHelmCommandPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmCommand -skipSealedSecrets -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}
