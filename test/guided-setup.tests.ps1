

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$location = join-path $PSScriptRoot '..'
push-location ($location)

'./test/mock.ps1',
'./test/pass.ps1',
'./setup/core/common/question.ps1',
'./setup/core/common/k8s.ps1',
'./setup/core/common/codedx.ps1',
'./setup/core/common/prereqs.ps1',
'./setup/powershell-algorithms/data-structures.ps1',
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

Describe 'Generate Setup Commands' {

	BeforeEach {
		$global:kubeContexts = 'minikube','EKS','AKS','Other','OpenShift'
		$global:prereqsSatisified = $false
		$global:k8sport = 8443
		$global:caCertCertificateExists = $true
		$global:caCertFileExists = $true
		$global:keystorePasswordValid = $true
		$global:csrSupportsV1Beta1 = $true
	}

	AfterEach {
		if ($DebugPreference -ne 'Continue') {
			Clear-Host
		}
	}

	It '(01) Should generate run-setup.ps1' {
	
		Set-DefaultPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1
		
		join-path $TestDrive run-setup.ps1 | Should -Exist
	}

	It '(02) Should generate run-prereqs.ps1 and run-setup.ps1' {
	
		Set-DefaultPass 2 # save w/ prereqs command

		New-Mocks
		. ./guided-setup.ps1
		
		join-path $TestDrive run-setup.ps1 | Should -Exist
		join-path $TestDrive run-prereqs.ps1 | Should -Exist
	}

	It '(03) Should generate minikube setup.ps1 command without tool orchestration' -Tag 'No Tool Orchestration' {
	
		Set-DefaultPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

 	It '(04) Should generate minikube setup.ps1 command with tool orchestration and subordinate database' -Tag 'Tool Orchestration' {
	
 		Set-UseToolOrchestrationAndSubordinateDatabasePass 1

 		New-Mocks
 		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
 		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(05) Should generate minikube setup.ps1 command with external database' -Tag 'External Database' {
	
		Set-ExternalDatabasePass 1

		New-Mocks
		. ./guided-setup.ps1

	   	$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
	   	$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -skipIngressAssumesNginx -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
   }

   It '(06) Should generate EKS setup.ps1 command with AWS Classic Load Balancer' -Tag 'Ingress' {
	
		Set-ClassicLoadBalancerIngressPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(07) Should generate AKS setup.ps1 command with NGINX and Let''s Encrypt' -Tag 'Ingress' {
	
		Set-NginxLetsEncryptWithLoadBalancerIpPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'codedx.com' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -nginxMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -workflowStepMinimumRunTimeSeconds 3 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -usePnsContainerRuntimeExecutor -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -nginxIngressControllerNamespace 'nginx' -nginxIngressControllerLoadBalancerIP '10.0.0.1' -letsEncryptCertManagerNamespace 'cert-manager' -letsEncryptCertManagerIssuer 'letsencrypt-staging' -letsEncryptCertManagerRegistrationEmailAddress 'support@codedx.com'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(08) Should generate EKS setup.ps1 command with node selectors and pod tolerations' -Tag 'Selectors/Tolerations' {
	
		Set-NodeSelectorAndPodTolerationsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -codeDxNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes')) -codeDxNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','codedx-web')) -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -masterDatabaseNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes')) -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(09) Should generate EKS setup.ps1 command with all node selectors and pod tolerations' -Tag 'Selectors/Tolerations' {
	
		Set-AllNodeSelectorAndPodTolerationsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -codeDxNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-1')) -codeDxNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','codedx-web')) -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -subordinateDatabaseNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-3')) -subordinateDatabaseNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','subordinate-db')) -masterDatabaseNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-2')) -masterDatabaseNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','master-db')) -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-4')) -toolServiceNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','tool-service')) -minioNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-5')) -minioNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','minio')) -workflowControllerNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-6')) -workflowControllerNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','workflow-controller')) -toolNodeSelector ([Tuple``2[string,string]]::new('alpha.eksctl.io/nodegroup-name','codedx-nodes-7')) -toolNoScheduleExecuteToleration ([Tuple``2[string,string]]::new('host','tools')) -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(10) Should generate EKS setup.ps1 command with recommended resources' -Tag 'Resources' {
	
		Set-RecommendedResourcesPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(11) Should generate minikube setup.ps1 command with Docker image names and private registry' -Tag 'Docker' {
	
		Set-DockerImageNamesAndPrivateRegistryPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTools 'codedx-tools' -imageCodeDxToolsMono 'codedx-toolsmono' -imageNewAnalysis 'codedx-newanalysis' -imageSendResults 'codedx-sendresults' -imageSendErrorResults 'codedx-senderrorresults' -imageToolService 'codedx-toolservice' -imagePrepare 'codedx-prepare' -imagePreDelete 'codedx-cleanup' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMariaDB 'codedx-mariadb' -imageMinio 'minio' -imageWorkflowController 'codedx-workflow-controller' -imageWorkflowExecutor 'codedx-workflow-executor' -dockerImagePullSecretName 'private-reg' -dockerRegistry 'private-reg-host' -dockerRegistryUser 'private-reg-username' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -dockerRegistryPwd 'private-reg-password' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(12) Should generate minikube setup.ps1 command with custom cacerts file and extra certificates' -Tag 'Certificates' {
	
		Set-ConfigCertsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -caCertsFileNewPwd 'changed' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -extraCodeDxTrustedCaCertPaths @('extra1.pem','extra2.pem')"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(13) Should generate minikube setup.ps1 command with custom resources' -Tag 'Resources' {
	
		Set-UseCustomResourcesPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '501Mi' -dbMasterMemoryReservation '502Mi' -dbSlaveMemoryReservation '503Mi' -toolServiceMemoryReservation '504Mi' -minioMemoryReservation '505Mi' -workflowMemoryReservation '506Mi' -codeDxCPUReservation '1001m' -dbMasterCPUReservation '1002m' -dbSlaveCPUReservation '1003m' -toolServiceCPUReservation '1004m' -minioCPUReservation '1005m' -workflowCPUReservation '1006m' -codeDxEphemeralStorageReservation '1025Mi' -dbMasterEphemeralStorageReservation '1026Mi' -dbSlaveEphemeralStorageReservation '1027Mi' -toolServiceEphemeralStorageReservation '1028Mi' -minioEphemeralStorageReservation '1029Mi' -workflowEphemeralStorageReservation '1030Mi' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 20 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 25 -dbSlaveVolumeSizeGiB 30 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 35 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(14) Should generate minikube setup.ps1 command with SAML configuration' -Tag 'SAML' {
	
		Set-UseSamlPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'codedx.com' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -useSaml -skipUseRootDatabaseUser -samlIdentityProviderMetadataPath 'idp-metadata.xml' -samlAppName 'codedxclient' -samlKeystorePwd 'my-keystore-password' -samlPrivateKeyPwd 'my-private-key-password' -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(15) Should generate minikube setup.ps1 command with some Docker image names' -Tag 'Docker' {
	
		Set-SomeDockerImageNames 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxToolsMono 'codedx-toolsmono' -imageNewAnalysis 'codedx-newanalysis' -imageSendResults 'codedx-sendresults' -imageSendErrorResults 'codedx-senderrorresults' -imageToolService 'codedx-toolservice' -imagePrepare 'codedx-prepare' -imagePreDelete 'codedx-cleanup' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMariaDB 'codedx-mariadb' -imageMinio 'minio' -imageWorkflowController 'codedx-workflow-controller' -imageWorkflowExecutor 'codedx-workflow-executor' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(16) Should generate minikube setup.ps1 command with default reservations' -Tag 'Resources' {
	
		Set-PassWithDefaultResourceReservations 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(17) Should generate minikube setup.ps1 command with custom, accepting default, reservations' -Tag 'Resources' {
	
		Set-PassWithCustomAcceptingDefaultResourceReservations 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(18) Should generate EKS, GitOps setup.ps1 command with AWS Classic Load Balancer' -Tag 'Ingress' {
	
		Set-ClassicLoadBalancerIngressGitOpsPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmOperator -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(19) Should generate AKS setup.ps1 command with NGINX, Let''s Encrypt, and no LoadBalancer IP' -Tag 'Ingress' {
	
		Set-NginxLetsEncryptWithoutLoadBalancerIpPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -codeDxDnsName 'codedx.com' -clusterCertificateAuthorityCertPath 'ca.crt' -codeDxMemoryReservation '8192Mi' -dbMasterMemoryReservation '8192Mi' -dbSlaveMemoryReservation '8192Mi' -toolServiceMemoryReservation '500Mi' -minioMemoryReservation '5120Mi' -workflowMemoryReservation '500Mi' -nginxMemoryReservation '500Mi' -codeDxCPUReservation '2000m' -dbMasterCPUReservation '2000m' -dbSlaveCPUReservation '1000m' -minioCPUReservation '2000m' -codeDxEphemeralStorageReservation '2048Mi' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -workflowStepMinimumRunTimeSeconds 3 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -usePnsContainerRuntimeExecutor -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -nginxIngressControllerNamespace 'nginx' -letsEncryptCertManagerNamespace 'cert-manager' -letsEncryptCertManagerIssuer 'letsencrypt-staging' -letsEncryptCertManagerRegistrationEmailAddress 'support@codedx.com'"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(20) Should generate EKS, GitOps setup.ps1 command with AWS Classic Load Balancer and no TLS' -Tag 'Ingress' {
	
		Set-ClassicLoadBalancerIngressGitOpsNoTLSPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -useHelmOperator -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='http';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(21) Should generate run-setup.ps1 with Velero plug-in backup type' {
	
		Set-DefaultPassWithVelero 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -backupType 'velero' -namespaceVelero 'velerons' -backupScheduleCronExpression '0 4 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 32 -backupTimeToLiveHours 24 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(22) Should generate run-setup.ps1 with Velero Restic integration backup type' {
	
		Set-DefaultPassWithVeleroRestic 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(23) Should generate run-setup.ps1 with OpenShift switches' {
	
		Set-OpenShiftPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'OpenShift' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -workflowStepMinimumRunTimeSeconds 3 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -usePnsContainerRuntimeExecutor -createSCCs -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(24) Should generate run-setup.ps1 for Classic ELB with TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$true -useTls:$true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(25) Should generate run-setup.ps1 for Classic ELB without TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$true -useTls:$false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='http';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(26) Should generate run-setup.ps1 for Network ELB with TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$false -useTls:$true # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='ssl';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https';'service.beta.kubernetes.io/aws-load-balancer-type'='nlb'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(27) Should generate run-setup.ps1 for Network ELB without TLS' {

		Set-LoadBalancerIngressPass 1 -useClassicLoadBalancer:$false -useTls:$false # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipTLS -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='http';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https';'service.beta.kubernetes.io/aws-load-balancer-type'='nlb'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(28) Should generate minikube setup.ps1 command with Docker image names and no orchestration' -Tag 'Docker' {
	
		Set-DockerImageNamesDatabaseNoOrchestration 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMariaDB 'codedx-mariadb' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(29) Should generate minikube setup.ps1 command with Docker image names and no database and no orchestration' -Tag 'Docker' {
	
		Set-DockerImageNamesNoDatabaseNoOrchestration 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTomcatInit 'codedx-tomcat-init' -storageClassName 'default' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -skipIngressAssumesNginx -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}	

	It '(30) Should generate minikube setup.ps1 command with Docker image names and no database and orchestration' -Tag 'Docker' {
	
		Set-DockerImageNamesNoDatabaseOrchestration 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -imageCodeDxTomcat 'codedx-tomcat' -imageCodeDxTools 'codedx-tools' -imageCodeDxToolsMono 'codedx-toolsmono' -imageNewAnalysis 'codedx-newanalysis' -imageSendResults 'codedx-sendresults' -imageSendErrorResults 'codedx-senderrorresults' -imageToolService 'codedx-toolservice' -imagePrepare 'codedx-prepare' -imagePreDelete 'codedx-cleanup' -imageCodeDxTomcatInit 'codedx-tomcat-init' -imageMinio 'minio' -imageWorkflowController 'codedx-workflow-controller' -imageWorkflowExecutor 'codedx-workflow-executor' -storageClassName 'default' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -skipIngressAssumesNginx -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(31) Should generate minikube setup.ps1 command with anonymous redirect' -Tag 'Docker' {
	
		Set-DockerImageRedirect 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -redirectDockerHubReferencesTo 'myregistry.codedx.com' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}	

	It '(32) Should generate minikube setup.ps1 command with private registry redirect' -Tag 'Docker' {
	
		Set-DockerImagePrivateRedirect 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -dockerImagePullSecretName 'private-reg' -dockerRegistry 'private-reg-host' -dockerRegistryUser 'private-reg-username' -redirectDockerHubReferencesTo 'private-reg-host' -storageClassName 'default' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -dockerRegistryPwd 'private-reg-password' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}	

	It '(33) Should generate setup.ps1 command with PNS' -Tag 'PNS' {
	
		Set-RequiresPnsPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'Other' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -workflowStepMinimumRunTimeSeconds 3 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -usePnsContainerRuntimeExecutor -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}	

	It '(34) Should generate setup.ps1 command without PNS' -Tag 'PNS' {
	
		Set-OtherDockerPass 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'Other' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -backupType 'velero-restic' -namespaceVelero 'velero-ns' -backupScheduleCronExpression '0 5 * * *' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -backupDatabaseTimeoutMinutes 33 -backupTimeToLiveHours 25 -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(35) Should generate minikube setup.ps1 command with external database and defaults' -Tag 'External Database' {
	
		Set-ExternalDatabasePass 1

		New-Mocks
		. ./guided-setup.ps1

	   	$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -skipIngressEnabled -skipIngressAssumesNginx -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -externalDatabaseHost 'my-external-db-host' -externalDatabaseName 'codedxdb' -externalDatabaseUser 'codedx' -externalDatabasePwd 'codedx-db-password' -skipDatabase -externalDatabasePort 3306 -externalDatabaseServerCert 'db-ca.crt' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(36) Should generate EKS, GitOps Toolkit setup.ps1 command with AWS Classic Load Balancer' -Tag 'Ingress' {
	
		Set-ClassicLoadBalancerIngressGitOpsToolkitPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -caCertsFilePath 'cacerts' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -useHelmController -sealedSecretsNamespace 'adm' -sealedSecretsControllerName 'sealed-secrets' -sealedSecretsPublicKeyPath 'sealed-secrets.pem' -codedxAdminPwd 'my-codedx-password' -caCertsFilePwd 'changeit' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(37) Should use cert-manager ClusterIssuer signer without Tool Orchestration' {
	
		Set-UseCertManagerClusterIssuerNoToolOrchestration 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(38) Should use cert-manager ClusterIssuer signer' {
	
		Set-UseCertManagerClusterIssuer 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer' -csrSignerNameToolOrchestration 'clusterissuers.cert-manager.io/ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(39) Should use cert-manager Issuer signers' {
	
		Set-UseCertManagerIssuers 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'issuers.cert-manager.io/cdx-app.ca-issuer' -csrSignerNameToolOrchestration 'issuers.cert-manager.io/cdx-svc.ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipPSPs -skipNetworkPolicies -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(40) Should use cert-manager ClusterIssuer signer because legacy-unknown is unsupported without tool orchestration' {
	
		Set-MustUseCertManagerClusterIssuerNoToolOrchestration 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(41) Should use cert-manager Issuer signers because legacy-unknown is unsupported' {
	
		Set-MustUseCertManagerClusterIssuer 1 # save w/o prereqs command

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'minikube' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -csrSignerNameCodeDx 'issuers.cert-manager.io/cdx-app.ca-issuer' -csrSignerNameToolOrchestration 'issuers.cert-manager.io/cdx-svc.ca-issuer' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 9443 -dbVolumeSizeGiB 64 -dbSlaveVolumeSizeGiB 64 -dbSlaveReplicaCount 1 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -minioVolumeSizeGiB 64 -toolServiceReplicas 2 -namespaceToolOrchestration 'cdx-svc' -releaseNameToolOrchestration 'codedx-tool-orchestration' -toolServiceApiKey 'my-tool-service-password' -minioAdminPwd 'my-minio-password' -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}

	It '(42) Should generate EKS setup.ps1 command with AWS Internal Classic Load Balancer' -Tag 'Ingress' {
	
		Set-ClassicLoadBalancerInternalIngressPass 1

		New-Mocks
		. ./guided-setup.ps1

		$runSetupFile = join-path $TestDrive run-setup.ps1
		$runSetupFile | Should -Exist
		$expectedParams = "-kubeContextName 'EKS' -kubeApiTargetPort '8443' -namespaceCodeDx 'cdx-app' -releaseNameCodeDx 'codedx' -clusterCertificateAuthorityCertPath 'ca.crt' -storageClassName 'default' -serviceTypeCodeDx 'LoadBalancer' -csrSignerNameCodeDx 'kubernetes.io/legacy-unknown' -csrSignerNameToolOrchestration 'kubernetes.io/legacy-unknown' -codedxAdminPwd 'my-codedx-password' -codedxDatabaseUserPwd 'my-db-user-password' -skipIngressEnabled -skipIngressAssumesNginx -skipUseRootDatabaseUser -codeDxVolumeSizeGiB 64 -codeDxTlsServicePortNumber 443 -dbVolumeSizeGiB 64 -dbSlaveReplicaCount 0 -mariadbRootPwd 'my-root-db-password' -mariadbReplicatorPwd 'my-replication-db-password' -skipToolOrchestration -skipNginxIngressControllerInstall -skipLetsEncryptCertManagerInstall -serviceAnnotationsCodeDx @{'service.beta.kubernetes.io/aws-load-balancer-backend-protocol'='https';'service.beta.kubernetes.io/aws-load-balancer-internal'='true';'service.beta.kubernetes.io/aws-load-balancer-ssl-cert'='arn:value';'service.beta.kubernetes.io/aws-load-balancer-ssl-ports'='https'}"
		Test-SetupParameters $PSScriptRoot $runSetupFile $TestDrive $expectedParams | Should -BeTrue
	}
}
