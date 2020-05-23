<#PSScriptInfo
.VERSION 1.0.1
.GUID 6b1307f7-7098-4c65-9a86-8478840ad4cd
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for the deployment of Code Dx and Code Dx Orchestration.
#>



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
	[switch]   $ingressEnabled,
	[switch]   $ingressAssumesNginx,
	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls,
	[switch]   $skipDatabase) {
 
	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	$imagePullSecretYaml = 'codedxTomcatImagePullSecrets: []'
	if (-not ([string]::IsNullOrWhiteSpace($tomcatImagePullSecretName))) {

		$imagePullSecretYaml = @'
codedxTomcatImagePullSecrets:
- name: {0}
'@ -f $tomcatImagePullSecretName

		New-ImagePullSecret $namespace $tomcatImagePullSecretName $dockerRegistry $dockerRegistryUser $dockerRegistryPwd
	}

	$psp = 'false'
	if ($enablePSPs) {
		$psp = 'true'
	}
	$networkPolicy = 'false'
	if ($enableNetworkPolicies) {
		$networkPolicy = 'true'
	}
	$enableDb = 'true' 
	if ($skipDatabase) {
		$enableDb = 'false'
	}

	$codeDxFullName = Get-CodeDxChartFullName $releaseName

	$tlsEnabled = 'false'
	$tlsSecretName = "$codeDxFullName-tls"
	$tlsCertFile = "$codeDxFullName.pem"
	$tlsKeyFile = "$codeDxFullName.key"
	if ($configureTls) {
		$tlsEnabled = 'true'

		New-Certificate $caCertPathCodeDx $codeDxFullName $codeDxFullName $tlsCertFile $tlsKeyFile $namespace @()
		New-CertificateSecret $namespace $tlsSecretName $tlsCertFile $tlsKeyFile
	}

	$ingress = 'false'
	if ($ingressEnabled) {
		$ingress = 'true'
	}

	$ingressNginxAssumption = 'false'
	if ($ingressAssumesNginx) {
		$ingressNginxAssumption = 'true'
	}

	$ingressNamespaceSelector = ''
	if ('' -ne $ingressControllerNamespace) {
		$ingressNamespaceSelector = @'
    ingressSelectors:
    - namespaceSelector:
        matchLabels:
          name: {0}
'@ -f $ingressControllerNamespace
	}

	$defaultKeyStorePwd = 'changeit'

	$values = @'
codedxAdminPassword: '{0}'
codedxTomcatPort: {24}
codedxTlsTomcatPort: {25}
persistence:
  size: {12}Gi
  storageClass: {18}
codedxTls:
  enabled: {5}
  secret: {6}
  certFile: {7}
  keyFile: {8}
service:
  type: {26}
  annotations: {27}
ingress:
  enabled: {14}
  annotations: {21}
  assumeNginxIngressController: {29}
  hosts:
  - name: {13}
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
{17}
  mariadb:
    master:
      create: {4}
    slave:
      create: {4}
codedxTomcatImage: {1}
{2}
{19}
mariadb:
  enabled: {28}
  rootUser:
    password: '{9}'
  replication:
    password: '{10}'
  master:
    persistence:
      storageClass: {18}
      size: {11}Gi
{20}
  slave:
    replicas: {16}
    persistence:
      storageClass: {18}
      size: {15}Gi
      backup:
        size: {15}Gi
{23}
cacertsFile: ''
cacertsFilePwd: '{22}'
'@ -f $adminPwd, $tomcatImage, $imagePullSecretYaml, `
$psp, $networkPolicy, `
$tlsEnabled, $tlsSecretName, $tlsCertFile, $tlsKeyFile, `
$mariadbRootPwd, $mariadbReplicatorPwd, `
$dbVolumeSizeGiB, $codeDxVolumeSizeGiB, $codeDxDnsName, $ingress, `
$dbSlaveVolumeSizeGiB, $dbSlaveReplicaCount, $ingressNamespaceSelector, $storageClassName, `
(Format-ResourceLimitRequest -limitMemory $codeDxMemoryLimit -limitCPU $codeDxCPULimit -limitEphemeralStorage $codeDxEphemeralStorageLimit), `
(Format-ResourceLimitRequest -limitMemory $dbMasterMemoryLimit -limitCPU $dbMasterCPULimit -limitEphemeralStorage $dbMasterEphemeralStorageLimit -indent 4), `
(ConvertTo-YamlMap $ingressAnnotations), `
$defaultKeyStorePwd, `
(Format-ResourceLimitRequest -limitMemory $dbSlaveMemoryLimit -limitCPU $dbSlaveCPULimit -limitEphemeralStorage $dbSlaveEphemeralStorageLimit -indent 4), `
$codeDxTomcatPortNumber, $codeDxTlsTomcatPortNumber, `
$serviceTypeCodeDx, (ConvertTo-YamlMap $serviceAnnotationsCodeDx), `
$enableDb, $ingressNginxAssumption

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

	$protocol = 'http'
	$codedxPort = $codeDxTomcatPortNumber
	$tlsConfig = 'false'
	$tlsMinioCertSecret = ''
	$tlsToolServiceCertSecret = ''
	$codedxCaConfigMap = ''

	$toolOrchestrationFullName = Get-CodeDxToolOrchestrationChartFullName $toolServiceReleaseName

	if ($configureTls) {
		$protocol = 'https'
		$codedxPort = $codeDxTlsTomcatPortNumber
		$tlsConfig = 'true'

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

	$psp = 'false'
	if ($enablePSPs) {
		$psp = 'true'
	}
	$networkPolicy = 'false'
	if ($enableNetworkPolicies) {
		$networkPolicy = 'true'
	}

	$values = @'
argo:
  installCRD: false
  controller:
{27}

minio:
  global:
    minio:
      accessKeyGlobal: '{0}'
      secretKeyGlobal: '{1}'
  tls:
    enabled: {13}
    certSecret: {14}
    publicCrt: 'minio.pem'
    privateKey: 'minio.key'
  persistence:
    storageClass: {24}
    size: {21}Gi
{28}

minioTlsTrust:
  configMapName: {29}
  configMapPublicCertKeyName: 'minio.pem'

podSecurityPolicy:
  tws:
    create: {16}
  twsWorkflows:	
    create: {16}
  argo:
    create: {16}
  minio:
    create: {16}

numReplicas: {12}

networkPolicy:
  toolServiceEnabled: {17}
  twsWorkflowsEnabled: {17}
  argoEnabled: {17}
  minioEnabled: {17}      
  kubeApiTargetPort: {25}
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: '{2}'
  
codedxBaseUrl: '{18}'
codedxTls:
  enabled: {19}
  caConfigMap: {20}
  
toolServiceApiKey: '{4}'
toolServiceTls:
  secret: {15}
  certFile: 'toolsvc.pem'
  keyFile: 'toolsvc.key'
  
imagePullSecretKey: '{5}'
imageNameCodeDxTools: '{6}'
imageNameCodeDxToolsMono: '{7}' 
imageNameNewAnalysis: '{8}' 
imageNameSendResults: '{9}' 
imageNameSendErrorResults: '{10}' 
toolServiceImageName: '{11}' 
imageNameHelmPreDelete: '{23}' 
{22}

{26}
'@ -f $minioUsername,`
$minioPwd,$codedxNamespace,$codedxReleaseName,$apiKey,`
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

function Set-TrustedCerts([string] $workDir, 
	[string]   $waitSeconds,
	[string]   $codedxNamespace,
	[string]   $codedxReleaseName,
	[string[]] $extraValuesPaths,
	[string]   $caCertsFilePwd,
	[string]   $caCertsFileNewPwd,
	[string[]] $trustedCertPaths) {

	$caCertsFilePath = './cacerts'
	if (test-path $caCertsFilePath) {
		remove-item $caCertsFilePath -force
	}

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	$chartFolderCaCertsFilePath = join-path $chartFolder $caCertsFilePath

	# if cacerts already exists in the chart folder via -extraCodeDxChartFilesPaths, use 
	# that copy; otherwise, pull a copy from the running Code Dx pod
	if (test-path $chartFolderCaCertsFilePath) {
		copy-item $chartFolderCaCertsFilePath $caCertsFilePath
	} else {
		$podName = Get-RunningCodeDxPodName $codedxNamespace
		$podFile = "$podName`:/etc/ssl/certs/java/cacerts"

		kubectl -n $codedxNamespace cp $podFile $caCertsFilePath
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to copy out cacerts file, kubectl exited with code $LASTEXITCODE."
		}
	}

	# set cacerts password
	$keystorePwd = $caCertsFilePwd
	if ('' -ne $caCertsFileNewPwd -and $caCertsFilePwd -ne $caCertsFileNewPwd) {
		$keystorePwd = $caCertsFileNewPwd
	}
	Set-KeystorePassword $caCertsFilePath $caCertsFilePwd $keystorePwd 

	Import-TrustedCaCerts $caCertsFilePath $keystorePwd $trustedCertPaths

	# move edited cacerts file to chart directory where it can be found during chart install
	copy-item $caCertsFilePath $chartFolder -Force

	$values = @'
cacertsFile: cacerts
cacertsFilePwd: {0}
'@ -f $keystorePwd

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

	$networkPolicy = 'false'
	if ($enableNetworkPolicies) {
		$networkPolicy = 'true'
	}

	$codedxOrchestrationPropsKey = 'codedx-orchestration-props-key'
	"tws.api-key = $toolServiceApiKey" | Out-File $codedxOrchestrationPropsKey -Encoding ascii -Force

	New-FileSecret $codedxNamespace $codedxOrchestrationPropsKey $codedxOrchestrationPropsKey

	$values = @'
codedxProps:
  internalExtra:
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

	$usePSP = 'false'
	if ($enablePSPs) {
		$usePSP = 'true'
	}

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
	
	$usePSP = 'false'
	if ($enablePSPs) {
		$usePSP = 'true'
	}

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
