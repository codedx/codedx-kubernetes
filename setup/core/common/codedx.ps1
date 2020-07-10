<#PSScriptInfo
.VERSION 1.0.3
.GUID 6b1307f7-7098-4c65-9a86-8478840ad4cd
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for the deployment of Code Dx and Code Dx Orchestration.
#>

'utils.ps1',
'k8s.ps1',
'helm.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Get-CodeDxPdSecretName([string] $releaseName) {
	"$releaseName-codedx-pd"
}

function New-CodeDxPdSecret([string] $namespace, [string] $releaseName, 
	[string] $adminPwd, [string] $caCertsFilePwd,
	[string] $externalDbUser, [string] $externalDbPwd) {

	$data = @{"admin-password"=$adminPwd;"cacerts-password"=$caCertsFilePwd}
	
	if ('' -ne $externalDbUser) {
		$data['mariadb-codedx-username'] = $externalDbUser
	}
	if ('' -ne $externalDbPwd) {
		$data['mariadb-codedx-password'] = $externalDbPwd
	}

	New-GenericSecret $namespace (Get-CodeDxPdSecretName $releaseName) $data
}

function New-CodeDxDeployment([string] $codeDxDnsName,
	[int]      $codeDxTomcatPortNumber,
	[int]      $codeDxTlsTomcatPortNumber,
    [string]   $workDir, 
	[int]      $waitSeconds,
	[string]   $caCertPathCodeDx,
	[string]   $namespace,
	[string]   $releaseName,
	[string]   $adminPwd,
	[string]   $tomcatImage,
	[string]   $tomcatImagePullSecretName,
	[string]   $dockerRegistry,
	[string]   $dockerRegistryUser,
	[string]   $dockerRegistryPwd,
	[string]   $mariadbRootPwd,
	[string]   $mariadbReplicatorPwd,
	[int]      $dbVolumeSizeGiB,
	[int]      $dbSlaveReplicaCount,
	[int]      $dbSlaveVolumeSizeGiB,
	[int]      $codeDxVolumeSizeGiB,	
	[string]   $storageClassName,
	[string]   $codeDxMemoryLimit,
	[string]   $dbMasterMemoryLimit,
	[string]   $dbSlaveMemoryLimit,
	[string]   $codeDxCPULimit,
	[string]   $dbMasterCPULimit,
	[string]   $dbSlaveCPULimit,
	[string]   $codeDxEphemeralStorageLimit,
	[string]   $dbMasterEphemeralStorageLimit,
	[string]   $dbSlaveEphemeralStorageLimit,
	[string[]] $extraValuesPaths,
	[string]   $serviceTypeCodeDx,
	[string[]] $serviceAnnotationsCodeDx,
	[string]   $ingressControllerNamespace,
	[string[]] $ingressAnnotations,
	[string]   $caCertsFilename,
	[string]   $caCertsFilePwd,
	[string]   $externalDbUrl,
	[string]   $externalDbUser,
	[string]   $externalDbPwd,
	[switch]   $ingressEnabled,
	[switch]   $ingressAssumesNginx,
	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls,
	[switch]   $skipDatabase,
	[switch]   $offlineMode) {
 
	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	New-CodeDxPdSecret $namespace $releaseName $adminPwd $caCertsFilePwd $externalDbUser $externalDbPwd

	# excluding "mariadb-password" from MariaDb credential secret because db.user is unspecfied
	$mariadbCredentialSecret = "$releaseName-mariadb-pd"
	New-GenericSecret $namespace $mariadbCredentialSecret @{"mariadb-root-password"=$mariadbRootPwd;"mariadb-replication-password"=$mariadbReplicatorPwd}

	$imagePullSecretYaml = 'codedxTomcatImagePullSecrets: []'
	if (-not ([string]::IsNullOrWhiteSpace($tomcatImagePullSecretName))) {

		$imagePullSecretYaml = @'
codedxTomcatImagePullSecrets:
- name: {0}
'@ -f $tomcatImagePullSecretName

		New-ImagePullSecret $namespace $tomcatImagePullSecretName $dockerRegistry $dockerRegistryUser $dockerRegistryPwd
	}

	$psp = $enablePSPs.ToString().ToLower()
	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()
	$enableDb = (-not $skipDatabase).ToString().ToLower()

	$codeDxFullName = Get-CodeDxChartFullName $releaseName

	$tlsEnabled = $configureTls.ToString().ToLower()
	$tlsSecretName = "$codeDxFullName-tls"
	$tlsCertFile = "$codeDxFullName.pem"
	$tlsKeyFile = "$codeDxFullName.key"
	if ($configureTls) {
		New-Certificate $caCertPathCodeDx $codeDxFullName $codeDxFullName $tlsCertFile $tlsKeyFile $namespace @()
		New-CertificateSecret $namespace $tlsSecretName $tlsCertFile $tlsKeyFile
	}

	$ingress = $ingressEnabled.ToString().ToLower()
	$ingressNginxAssumption = $ingressAssumesNginx.ToString().ToLower()

	$ingressNamespaceSelector = ''
	if ('' -ne $ingressControllerNamespace) {
		$ingressNamespaceSelector = @'
    ingressSelectors:
    - namespaceSelector:
        matchLabels:
          name: {0}
'@ -f $ingressControllerNamespace
	}

	$externalDb = ''
	if ('' -ne $externalDbUrl) {
		$externalDb = @'
  dbconnection:
    externalDbUrl: '{0}'
'@ -f $externalDbUrl
	}

	$defaultKeyStorePwd = 'changeit'

	$values = @'
existingSecret: '{0}'
codedxTomcatPort: {23}
codedxTlsTomcatPort: {24}
persistence:
  size: {11}Gi
  storageClass: {17}
codedxTls:
  enabled: {5}
  secret: {6}
  certFile: {7}
  keyFile: {8}
service:
  type: {25}
  annotations: {26}
ingress:
  enabled: {13}
  annotations: {20}
  assumeNginxIngressController: {28}
  hosts:
  - name: {12}
    tls: true
    tlsSecret: ingress-tls-secret
podSecurityPolicy:
  codedx:
    create: {3}
  mariadb:
    create: {3}
networkPolicy:
  codedx:
    create: {4}
    ldap: {4}
    ldaps: {4}
    http: {4}
    https: {4}
{16}
  mariadb:
    master:
      create: {4}
    slave:
      create: {4}
codedxTomcatImage: {1}
{2}
{18}
mariadb:
  enabled: {27}
  existingSecret: '{9}'
  db:
    user: ''
  master:
    persistence:
      storageClass: {17}
      size: {10}Gi
{19}
  slave:
    replicas: {15}
    persistence:
      storageClass: {17}
      size: {14}Gi
      backup:
        size: {14}Gi
{22}
cacertsFile: '{30}'
cacertsFilePwd: '{21}'
codedxProps:
  internalExtra:
  - type: values
    key: codedx-offline-props
    values:
    - "codedx.offline-mode = {31}"
{29}
'@ -f (Get-CodeDxPdSecretName $releaseName), $tomcatImage, $imagePullSecretYaml, `
$psp, $networkPolicy, `
$tlsEnabled, $tlsSecretName, 'tls.crt', 'tls.key', `
$mariadbCredentialSecret, `
$dbVolumeSizeGiB, $codeDxVolumeSizeGiB, $codeDxDnsName, $ingress, `
$dbSlaveVolumeSizeGiB, $dbSlaveReplicaCount, $ingressNamespaceSelector, $storageClassName, `
(Format-ResourceLimitRequest -limitMemory $codeDxMemoryLimit -limitCPU $codeDxCPULimit -limitEphemeralStorage $codeDxEphemeralStorageLimit), `
(Format-ResourceLimitRequest -limitMemory $dbMasterMemoryLimit -limitCPU $dbMasterCPULimit -limitEphemeralStorage $dbMasterEphemeralStorageLimit -indent 4), `
(ConvertTo-YamlMap $ingressAnnotations), `
$defaultKeyStorePwd, `
(Format-ResourceLimitRequest -limitMemory $dbSlaveMemoryLimit -limitCPU $dbSlaveCPULimit -limitEphemeralStorage $dbSlaveEphemeralStorageLimit -indent 4), `
$codeDxTomcatPortNumber, $codeDxTlsTomcatPortNumber, `
$serviceTypeCodeDx, (ConvertTo-YamlMap $serviceAnnotationsCodeDx), `
$enableDb, $ingressNginxAssumption, `
$externalDb, $caCertsFilename, $offlineMode.ToString().ToLower()

	$valuesFile = 'codedx-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	Invoke-HelmSingleDeployment 'Code Dx' $waitSeconds $namespace $releaseName $chartFolder $valuesFile $codeDxFullName 1 $extraValuesPaths
}

function New-ToolOrchestrationDeployment([string] $workDir, 
	[int]      $waitSeconds,
	[string]   $caCertPathOrchestrationComponents,
	[string]   $namespace,
	[string]   $codedxNamespace,
	[string]   $toolServiceReleaseName,
	[string]   $codedxReleaseName,
	[int]      $codeDxTomcatPortNumber,
	[int]      $codeDxTlsTomcatPortNumber,
	[int]      $numReplicas,
	[string]   $minioUsername,
	[string]   $minioPwd,
	[string]   $apiKey,
	[string]   $toolsImage,
	[string]   $toolsMonoImage,
	[string]   $newAnalysisImage,
	[string]   $sendResultsImage,
	[string]   $sendErrorResultsImage,
	[string]   $toolServiceImage,
	[string]   $preDeleteImageName,
	[string]   $imagePullSecretName,
	[string]   $dockerRegistry,
	[string]   $dockerRegistryUser,
	[string]   $dockerRegistryPwd,
	[int]      $minioVolumeSizeGiB,
	[string]   $storageClassName,
	[string]   $toolServiceMemoryLimit,
	[string]   $minioMemoryLimit,
	[string]   $workflowMemoryLimit,
	[string]   $toolServiceCPULimit,
	[string]   $minioCPULimit,
	[string]   $workflowCPULimit,	
	[string]   $toolServiceEphemeralStorageLimit,
	[string]   $minioEphemeralStorageLimit,
	[string]   $workflowEphemeralStorageLimit,	
	[int]      $kubeApiTargetPort,
	[string[]] $extraValuesPaths,
	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls) {

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	$toolServiceCredentialSecret = "$toolServiceReleaseName-tool-service-pd"
	New-GenericSecret $namespace $toolServiceCredentialSecret @{"api-key"=$apiKey}

	$minioCredentialSecret = "$toolServiceReleaseName-minio-pd"
	New-GenericSecret $namespace $minioCredentialSecret @{"access-key"=$minioUsername;"secret-key"=$minioPwd}

	$protocol = 'http'
	$codedxPort = $codeDxTomcatPortNumber
	$tlsConfig = $configureTls.ToString().ToLower()
	$tlsMinioCertSecret = ''
	$tlsToolServiceCertSecret = ''
	$codedxCaConfigMap = ''

	$toolOrchestrationFullName = Get-CodeDxToolOrchestrationChartFullName $toolServiceReleaseName

	if ($configureTls) {
		$protocol = 'https'
		$codedxPort = $codeDxTlsTomcatPortNumber

		$tlsMinioCertSecret = '{0}-minio-tls' -f $toolOrchestrationFullName
		$tlsToolServiceCertSecret = '{0}-tls' -f $toolOrchestrationFullName

		$codedxFullName = Get-CodeDxChartFullName $codedxReleaseName
		$codedxCaConfigMap = '{0}-ca-cert' -f $codedxFullName

		$toolOrchestrationFullName = Get-CodeDxToolOrchestrationChartFullName $toolServiceReleaseName
		$minioName = '{0}-minio' -f $toolServiceReleaseName

		New-Certificate $caCertPathOrchestrationComponents $toolOrchestrationFullName $toolOrchestrationFullName 'toolsvc.pem' 'toolsvc.key' $namespace @()
		New-Certificate $caCertPathOrchestrationComponents $minioName $minioName 'minio.pem' 'minio.key' $namespace @()

		New-CertificateSecret $namespace $tlsMinioCertSecret 'minio.pem' 'minio.key'

		$minioCertConfigMap = '{0}-minio-cert' -f $toolOrchestrationFullName
		New-CertificateConfigMap $namespace $minioCertConfigMap 'minio.pem'
		New-CertificateSecret $namespace $tlsToolServiceCertSecret 'toolsvc.pem' 'toolsvc.key'

		New-CertificateConfigMap $namespace $codedxCaConfigMap $caCertPathOrchestrationComponents
	}
	$codeDxOrchestrationFullName = Get-CodeDxChartFullName $codedxReleaseName
	$codedxBaseUrl = '{0}://{1}.{2}.svc.cluster.local:{3}/codedx' -f $protocol,$codeDxOrchestrationFullName,$codedxNamespace,$codedxPort

	$imagePullSecretYaml = 'toolServiceImagePullSecrets: []'
	if (-not ([string]::IsNullOrWhiteSpace($imagePullSecretName))) {

		$imagePullSecretYaml = @'
toolServiceImagePullSecrets:
- name: {0}
'@ -f $imagePullSecretName

		New-ImagePullSecret $namespace $imagePullSecretName $dockerRegistry $dockerRegistryUser $dockerRegistryPwd
	}

	$psp = $enablePSPs.ToString().ToLower()
	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()

	$values = @'
argo:
  installCRD: false
  controller:
{26}

minio:
  global:
    minio:
      existingSecret: '{0}'
  tls:
    enabled: {12}
    certSecret: {13}
    publicCrt: 'tls.crt'
    privateKey: 'tls.key'
  persistence:
    storageClass: {23}
    size: {20}Gi
{27}

minioTlsTrust:
  configMapName: {28}
  configMapPublicCertKeyName: 'minio.pem'

podSecurityPolicy:
  tws:
    create: {15}
  twsWorkflows:	
    create: {15}
  argo:
    create: {15}
  minio:
    create: {15}

numReplicas: {11}

networkPolicy:
  toolServiceEnabled: {16}
  twsWorkflowsEnabled: {16}
  argoEnabled: {16}
  minioEnabled: {16}      
  kubeApiTargetPort: {24}
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: '{1}'
  
codedxBaseUrl: '{17}'
codedxTls:
  enabled: {18}
  caConfigMap: {19}
  
existingSecret: '{3}'
toolServiceTls:
  secret: {14}
  certFile: 'tls.crt'
  keyFile: 'tls.key'
  
imagePullSecretKey: '{4}'
imageNameCodeDxTools: '{5}'
imageNameCodeDxToolsMono: '{6}' 
imageNameNewAnalysis: '{7}' 
imageNameSendResults: '{8}' 
imageNameSendErrorResults: '{9}' 
toolServiceImageName: '{10}' 
imageNameHelmPreDelete: '{22}' 
{21}

{25}
'@ -f $minioCredentialSecret,`
$codedxNamespace,$codedxReleaseName,$toolServiceCredentialSecret,`
$imagePullSecretName,$toolsImage,$toolsMonoImage,$newAnalysisImage,$sendResultsImage,$sendErrorResultsImage,$toolServiceImage,$numReplicas,
$tlsConfig,$tlsMinioCertSecret,$tlsToolServiceCertSecret,
$psp,$networkPolicy,$codedxBaseUrl,`
$tlsConfig,$codedxCaConfigMap,$minioVolumeSizeGiB,$imagePullSecretYaml,$preDeleteImageName,$storageClassName, $kubeApiTargetPort, `
(Format-ResourceLimitRequest -limitMemory $toolServiceMemoryLimit -limitCPU $toolServiceCPULimit -limitEphemeralStorage $toolServiceEphemeralStorageLimit), `
(Format-ResourceLimitRequest -limitMemory $workflowMemoryLimit -limitCPU $workflowCPULimit -limitEphemeralStorage $workflowEphemeralStorageLimit -indent 4), `
(Format-ResourceLimitRequest -limitMemory $minioMemoryLimit -limitCPU $minioCPULimit -limitEphemeralStorage $minioEphemeralStorageLimit -indent 2), `
$minioCertConfigMap

	$valuesFile = 'toolsvc-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx-tool-orchestration)
	
	Invoke-HelmSingleDeployment 'Tool Orchestration' $waitSeconds $namespace $toolServiceReleaseName $chartFolder $valuesFile $toolOrchestrationFullName $numReplicas $extraValuesPaths
}

function Get-RunningCodeDxPodName([string] $codedxNamespace) {

	$name = kubectl -n $codedxNamespace get pod -l app=codedx --field-selector=status.phase=Running -o jsonpath='{.items[0].metadata.name}'
	if (0 -ne $LASTEXITCODE) {
		throw "Unable to get the name of a running Code Dx pod, kubectl returned exit code $LASTEXITCODE."
	}
	$name
}

function Get-RunningCodeDxKeystore([string] $codedxNamespace, [string] $outPath) {

	$podName = Get-RunningCodeDxPodName $codedxNamespace
	$podFile = "$podName`:/usr/local/openjdk-8/jre/lib/security/cacerts"

	kubectl -n $codedxNamespace cp $podFile $outPath
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to copy out cacerts file from '$podFile', kubectl exited with code $LASTEXITCODE."
	}
}

function Set-TrustedCerts([string] $workDir,
	[string]   $waitSeconds,
	[string]   $codedxNamespace,
	[string]   $codedxReleaseName,
	[string[]] $extraValuesPaths,
	[string]   $adminPwd,
	[string]   $keystorePwd,
	[string]   $externalDbUser,
	[string]   $externalDbPwd,
	[switch]   $offlineMode) {

	New-CodeDxPdSecret $codedxNamespace $codedxReleaseName $adminPwd $keystorePwd $externalDbUser $externalDbPwd
	
	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	
	$values = @'
cacertsFile: cacerts
codedxProps:
  internalExtra:
  - type: values
    key: codedx-offline-props
    values:
    - "codedx.offline-mode = {0}"
'@ -f $offlineMode.ToString().ToLower()

	$valuesFile = 'codedx-cacert-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$deploymentName = Get-CodeDxChartFullName $codedxReleaseName

	Invoke-HelmSingleDeployment 'Code Dx (Configure Certs)' $waitSeconds $codedxNamespace $codedxReleaseName $chartFolder $valuesFile $deploymentName 1 $extraValuesPaths
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to upgrade Code Dx for trusted certs, helm exited with code $LASTEXITCODE."
	}
}

function Set-UseToolOrchestration([string] $workDir, 
	[string] $waitSeconds,
	[string] $caCertPathToolService,
	[string] $namespace, [string] $codedxNamespace,
	[string] $toolServiceUrl, [string] $toolServiceApiKey,
	[string] $codedxReleaseName,
	[string] $caCertsFilePwd,
	[string] $caCertsFileNewPwd,
	[string[]] $extraValuesPaths,
	[switch] $enableNetworkPolicies) {

	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()

	$codedxOrchestrationPropsKey = 'codedx-orchestration-key-props'
	New-GenericSecret $codedxNamespace $codedxOrchestrationPropsKey @{$codedxOrchestrationPropsKey = "tws.api-key = ""$toolServiceApiKey"""}
	
	$values = @'
codedxProps:
  internalExtra:
  - type: values
    key: codedx-offline-props
    values:
    - "codedx.offline-mode = false"
  - type: secret
    name: {3}
    key: {3}
  - type: values
    key: codedx-orchestration-props
    values:
    - "tws.enabled = true"
    - "tws.service-url = {0}"
networkPolicy:
  codedx:
    toolService: {2}
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: {1}
'@ -f $toolServiceUrl, $namespace, $networkPolicy, $codedxOrchestrationPropsKey

	$valuesFile = 'codedx-orchestration-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	$deploymentName = Get-CodeDxChartFullName $codedxReleaseName

	Invoke-HelmSingleDeployment 'Code Dx (Configure Tool Orchestration)' $waitSeconds $codedxNamespace $codedxReleaseName $chartFolder $valuesFile $deploymentName 1 $extraValuesPaths
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to upgrade Code Dx release for tool orchestration, helm exited with code $LASTEXITCODE."
	}
}

function Add-LetsEncryptCertManager([string] $namespace, [string] $codeDxNamespace,
	[string] $registrationEmailAddress, [string] $stagingIssuerFile, [string] $productionIssuerFile,
	[string] $certManagerRoleFile, [string] $certManagerRoleBindingFile, [string] $httpSolverRoleBindingFile,
	[string] $waitSeconds,
	[switch] $enablePSPs) {

	kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/v0.13.0/deploy/manifests/00-crds.yaml
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add cert-manager CRDs, helm exited with code $LASTEXITCODE."
	}

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}

	if (-not (Test-Namespace $codeDxNamespace)) {
		New-Namespace  $codeDxNamespace
	}

	Add-HelmRepo jetstack https://charts.jetstack.io

	$usePSP = $enablePSPs.ToString().ToLower()

	helm upgrade --namespace $namespace --install --reuse-values cert-manager jetstack/cert-manager --version v0.13.0 --set global.podSecurityPolicy.enabled=$usePSP
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to upgrade/install cert-manager, helm exited with code $LASTEXITCODE."
	}

	Wait-Deployment 'Add cert-manager' $waitSeconds $namespace 'cert-manager' 1
	Wait-Deployment 'Add cert-manager (cert-manager-cainjector)' $waitSeconds $namespace 'cert-manager-cainjector' 1
	Wait-Deployment 'Add cert-manager (cert-manager-webhook)' $waitSeconds $namespace 'cert-manager-webhook' 1

	$issuerTemplate = @'
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: letsencrypt-{1}
spec:
  acme:
    server: {2}
    email: {0}
    privateKeySecretRef:
      name: letsencrypt-{1}
    solvers:
    - http01:
        ingress:
          class: nginx
'@
	$issuerTemplate -f $registrationEmailAddress,'staging','https://acme-staging-v02.api.letsencrypt.org/directory' | out-file $stagingIssuerFile -Encoding ascii -Force
	$issuerTemplate -f $registrationEmailAddress,'prod','https://acme-v02.api.letsencrypt.org/directory' | out-file $productionIssuerFile -Encoding ascii -Force

	@'
apiVersion: rbac.authorization.k8s.io/v1
kind: Role
metadata:
  name: privileged-psp-role
rules:
- apiGroups:
  - extensions
  resourceNames:
  - privileged
  resources:
  - podsecuritypolicies
  verbs:
  - use
'@ | out-file $certManagerRoleFile -Encoding ascii -Force

	@'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-psp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: privileged-psp-role
subjects:
- kind: ServiceAccount
  name: cert-manager
  namespace: {0}
- kind: ServiceAccount
  name: cert-manager-cainjector
  namespace: {0}
- kind: ServiceAccount
  name: cert-manager-webhook
  namespace: {0}
'@ -f $namespace | out-file $certManagerRoleBindingFile -Encoding ascii -Force

	@'
apiVersion: rbac.authorization.k8s.io/v1
kind: RoleBinding
metadata:
  name: cert-manager-psp
roleRef:
  apiGroup: rbac.authorization.k8s.io
  kind: Role
  name: privileged-psp-role
subjects:
- kind: ServiceAccount
  name: default
  namespace: {0}
'@ -f $codeDxNamespace | out-file $httpSolverRoleBindingFile -Encoding ascii -Force
	
	($namespace,       $stagingIssuerFile),
	($namespace,       $productionIssuerFile),
	($namespace,       $certManagerRoleFile),
	($codeDxNamespace, $certManagerRoleFile),
	($namespace,       $certManagerRoleBindingFile),
	($codeDxNamespace, $httpSolverRoleBindingFile) | 
	ForEach-Object {
		$namespace = $_[0]
		$file = $_[1]
		kubectl -n $namespace apply -f $file
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to create cert-manager resource in namespace '$namespace' from file '$file'. kubectl exited with code $LASTEXITCODE."
		}
	}
}

function Add-NginxIngressLoadBalancerIP([string] $loadBalancerIP,
	[string] $namespace,
	[int]    $waitSeconds,
	[string] $nginxFile,
	[string] $priorityValuesFile,
	[string] $releaseName,
	[string] $cpuLimit,
	[string] $memoryLimit,
	[string] $ephemeralStorageLimit,
	[switch] $enablePSPs) {

	@'
controller:
  service:
    loadBalancerIP: {0}
'@ -f $loadBalancerIP | out-file $nginxFile -Encoding ascii -Force

	Add-NginxIngress $namespace $waitSeconds $nginxFile $priorityValuesFile $releaseName $cpuLimit $memoryLimit $ephemeralStorageLimit -enablePSPs:$enablePSPs
}

function Add-NginxIngress([string] [string] $namespace,
	[int] $waitSeconds,
	[string] $valuesFile,
	[string] $priorityValuesFile,
	[string] $releaseName,
	[string] $cpuLimit,
	[string] $memoryLimit,
	[string] $ephemeralStorageLimit,
	[switch] $enablePSPs) {

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	$priorityClassName = Get-CommonName "$releaseName-nginx-pc"
	if (-not (Test-PriorityClass $priorityClassName)) {
		New-PriorityClass $priorityClassName 20000
	}
	
	$usePSP = $enablePSPs.ToString().ToLower()

	@'
controller:
  priorityClassName: {0}
{1}
  admissionWebhooks:
    patch:
      priorityClassName: {0}
defaultBackend:
  priorityClassName: {0}
podSecurityPolicy:
  enabled: {2}
'@ -f $priorityClassName,(Format-ResourceLimitRequest -limitMemory $memoryLimit -limitCPU $cpuLimit -limitEphemeralStorage $ephemeralStorageLimit -indent 2),$usePSP | out-file $priorityValuesFile -Encoding ascii -Force
	
	Add-HelmRepo 'stable' 'https://kubernetes-charts.storage.googleapis.com'
	Invoke-HelmSingleDeployment 'nginx-ingress' $waitTimeSeconds $namespace 'nginx' 'stable/nginx-ingress' $valuesFile 'nginx-nginx-ingress-controller' 1 $priorityValuesFile
}

function Get-CodeDxChartFullName([string] $releaseName) {
	Get-HelmChartFullname $releaseName 'codedx'
}

function Get-CodeDxToolOrchestrationChartFullName([string] $releaseName) {
	Get-HelmChartFullname $releaseName 'codedx-tool-orchestration'
}

function Get-HelmChartFullname([string] $releaseName, [string] $chartName) {

	$fullname = $releaseName
	if ($releaseName -cne $chartName) {
		$fullname = "$releaseName-$chartName"
	}
	Get-CommonName $fullname
}

function Get-CommonName([string] $name) {

	# note: matches chart "sanitize" helper
	if ($name.length -gt 63) {
		$name = $name.Substring(0, 63)
	}
	$name.TrimEnd('-')
}

function Get-TrustedCaCertsFilePwd([string] $currentPwd, [string] $newPwd) {

	$pwd = $currentPwd
	if ('' -ne $newPwd -and $pwd -ne $newPwd) {
		$pwd = $newPwd
	}
	$pwd
}

function New-TrustedCaCertsFile([string] $basePath,
	[string]   $currentPwd, [string] $newPwd,
	[string[]] $certPathsToImport,
	[string]   $destinationDirectory) {

	$filePath = "./cacerts"
	if (Test-Path $filePath) {
		Remove-Item $filePath -force
	}
	Copy-Item $basePath $filePath

	$pwd = (Get-TrustedCaCertsFilePwd $currentPwd $newPwd)
	Set-KeystorePassword $filePath $currentPwd $pwd

	Import-TrustedCaCerts $filePath $pwd $certPathsToImport
	Copy-Item $filePath $destinationDirectory -Force
}

function Test-SetupPreqs([ref] $messages) {

	$messages.Value = @()
	$isCore = Test-IsCore
	if (-not $isCore) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
	}
	
	if ($isCore -and -not (Test-MinPsMajorVersion 7)) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core 7 or later'
	}
	
	'helm','kubectl','openssl','git','keytool' | foreach-object {
		$found = $null -ne (Get-AppCommandPath $_)
		if (-not $found) {
			$messages.Value += "Unable to continue because $_ cannot be found. Is $_ installed and included in your PATH?"
		}
		if ($found -and $_ -eq 'helm') {
			$helmVersion = Get-HelmVersionMajorMinor
			if ($null -eq $helmVersion) {
				$messages.Value += 'Unable to continue because helm version was not detected.'
			}
			
			$minimumHelmVersion = 3.1 # required for helm lookup function
			if ($helmVersion -lt $minimumHelmVersion) {
				$messages.Value += "Unable to continue with helm version $helmVersion, version $minimumHelmVersion or later is required"
			}
		}
	}
	$messages.Value.count -eq 0
}
