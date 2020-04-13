
function New-CodeDxDeployment([string] $codeDxDnsName,
    [string]   $workDir, 
	[int]      $waitSeconds,
	[string]   $caCertPathCodeDx,
	[string]   $namespace,
	[string]   $releaseName,
	[string]   $adminPwd,
	[string]   $tomcatImage,
	[string]   $tomcatImagePullSecretName,
	[string]   $dockerConfigJson,
	[string]   $mariadbRootPwd,
	[string]   $mariadbReplicatorPwd,
	[int]      $dbVolumeSizeGiB,
	[int]      $dbSlaveReplicaCount,
	[int]      $dbSlaveVolumeSizeGiB,
	[int]      $codeDxVolumeSizeGiB,	
	[string]   $storageClassName,
	[string]   $codeDxMemoryLimit,
	[string]   $dbMemoryLimit,
	[string]   $codeDxCPULimit,
	[string]   $dbCPULimit,
	[string[]] $extraValuesPaths,
	[string]   $ingressControllerNamespace,
	[string]   $ingressClusterIssuer,
	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls,
	[switch]   $configureIngress) {
 
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

		New-ImagePullSecret $namespace $tomcatImagePullSecretName $dockerConfigJson
	}

	$psp = 'false'
	if ($enablePSPs) {
		$psp = 'true'
	}
	$networkPolicy = 'false'
	if ($enableNetworkPolicies) {
		$networkPolicy = 'true'
	}

	$tlsEnabled = 'false'
	$tlsSecretName = 'cdx-codedx-app-codedx-tls'
	$tlsCertFile = 'codedx-app-codedx.pem'
	$tlsKeyFile = 'codedx-app-codedx.key'
	if ($configureTls) {
		$tlsEnabled = 'true'

		New-Certificate $caCertPathCodeDx 'codedx-app-codedx' 'codedx-app-codedx' $namespace @()
		New-CertificateSecret $namespace $tlsSecretName $tlsCertFile $tlsKeyFile
	}

	$ingressNamespaceSelector = ''
	$ingress = 'false'
	if ($configureIngress) {
		$ingress = 'true'
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
persistence:
  size: {12}Gi
  storageClass: {18}
codedxTls:
  enabled: {5}
  secret: {6}
  certFile: {7}
  keyFile: {8}
ingress:
  enabled: {14}
  annotations:
    nginx.ingress.kubernetes.io/proxy-read-timeout: "3600"
    nginx.ingress.kubernetes.io/proxy-body-size: "0"
    kubernetes.io/tls-acme: "true"
    cert-manager.io/cluster-issuer: "{21}"
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
{20}
cacertsFile: ''
cacertsFilePwd: '{22}'
'@ -f $adminPwd, $tomcatImage, $imagePullSecretYaml, `
$psp, $networkPolicy, `
$tlsEnabled, $tlsSecretName, $tlsCertFile, $tlsKeyFile, `
$mariadbRootPwd, $mariadbReplicatorPwd, `
$dbVolumeSizeGiB, $codeDxVolumeSizeGiB, $codeDxDnsName, $ingress, `
$dbSlaveVolumeSizeGiB, $dbSlaveReplicaCount, $ingressNamespaceSelector, $storageClassName, `
(Format-ResourceLimitRequest -limitMemory $codeDxMemoryLimit -limitCPU $codeDxCPULimit), `
(Format-ResourceLimitRequest -limitMemory $dbMemoryLimit -limitCPU $dbCPULimit -indent 4), `
$ingressClusterIssuer, `
$defaultKeyStorePwd

	$valuesFile = 'codedx-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	Invoke-HelmSingleDeployment 'Code Dx' $waitSeconds $namespace $releaseName $chartFolder $valuesFile 'codedx-app-codedx' 1 $extraValuesPaths
}

function New-ToolOrchestrationDeployment([string] $workDir, 
	[int]    $waitSeconds,
	[string] $caCertPathOrchestrationComponents,
	[string] $namespace,
	[string] $codedxNamespace,
	[string] $codedxReleaseName,
	[int]    $numReplicas,
	[string] $minioUsername,
	[string] $minioPwd,
	[string] $apiKey,
	[string] $toolsImage,
	[string] $toolsMonoImage,
	[string] $newAnalysisImage,
	[string] $sendResultsImage,
	[string] $sendErrorResultsImage,
	[string] $toolServiceImage,
	[string] $preDeleteImageName,
	[string] $imagePullSecretName,
	[string] $dockerConfigJson,
	[int]    $minioVolumeSizeGiB,
	[string] $storageClassName,
	[string] $toolServiceMemoryLimit,
	[string] $minioMemoryLimit,
	[string] $workflowMemoryLimit,
	[string] $toolServiceCPULimit,
	[string] $minioCPULimit,
	[string] $workflowCPULimit,	
	[int]    $kubeApiTargetPort,
	[string[]] $extraValuesPaths,
	[switch] $enablePSPs,
	[switch] $enableNetworkPolicies,
	[switch] $configureTls) {

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	$protocol = 'http'
	$codedxPort = '9090'
	$tlsConfig = 'false'
	$tlsMinioCertSecret = ''
	$tlsToolServiceCertSecret = ''
	$codedxCaConfigMap = ''

	if ($configureTls) {
		$protocol = 'https'
		$codedxPort = '9443'
		$tlsConfig = 'true'
		$tlsMinioCertSecret = 'cdx-toolsvc-minio-tls'
		$tlsToolServiceCertSecret = 'cdx-toolsvc-codedx-tool-orchestration-tls'
		$codedxCaConfigMap = 'cdx-codedx-ca-cert'

		New-Certificate $caCertPathOrchestrationComponents 'toolsvc-codedx-tool-orchestration' 'toolsvc-codedx-tool-orchestration' $namespace @()
		New-Certificate $caCertPathOrchestrationComponents 'toolsvc-minio' 'toolsvc-minio' $namespace @()

		New-CertificateSecret $namespace $tlsMinioCertSecret 'toolsvc-minio.pem' 'toolsvc-minio.key'
		New-CertificateConfigMap $namespace 'cdx-toolsvc-minio-cert' 'toolsvc-minio.pem'
		New-CertificateSecret $namespace $tlsToolServiceCertSecret 'toolsvc-codedx-tool-orchestration.pem' 'toolsvc-codedx-tool-orchestration.key'

		New-CertificateConfigMap $namespace $codedxCaConfigMap $caCertPathOrchestrationComponents
	}
	$codedxBaseUrl = '{0}://{1}-codedx.{2}.svc.cluster.local:{3}/codedx' -f $protocol,$codedxReleaseName,$codedxNamespace,$codedxPort

	$imagePullSecretYaml = 'toolServiceImagePullSecrets: []'
	if (-not ([string]::IsNullOrWhiteSpace($imagePullSecretName))) {

		$imagePullSecretYaml = @'
toolServiceImagePullSecrets:
- name: {0}
'@ -f $imagePullSecretName

		New-ImagePullSecret $namespace $imagePullSecretName $dockerConfigJson
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
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'
  persistence:
    storageClass: {24}
    size: {21}Gi
{28}

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'

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
  certFile: 'toolsvc-codedx-tool-orchestration.pem'
  keyFile: 'toolsvc-codedx-tool-orchestration.key'
  
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
(Format-ResourceLimitRequest -limitMemory $toolServiceMemoryLimit -limitCPU $toolServiceCPULimit), `
(Format-ResourceLimitRequest -limitMemory $workflowMemoryLimit -limitCPU $workflowCPULimit -indent 4), `
(Format-ResourceLimitRequest -limitMemory $minioMemoryLimit -limitCPU $minioCPULimit -indent 2)

	$valuesFile = 'toolsvc-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx-tool-orchestration)
	Invoke-HelmSingleDeployment 'Tool Orchestration' $waitSeconds $namespace 'toolsvc' $chartFolder $valuesFile 'toolsvc-codedx-tool-orchestration' $numReplicas $extraValuesPaths
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

	helm -n $codedxNamespace upgrade --values $valuesFile --reuse-values $codedxReleaseName $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to upgrade Code Dx for trusted certs, helm exited with code $LASTEXITCODE."
	}

	Wait-Deployment 'Helm Upgrade' $waitSeconds $codedxNamespace "$codedxReleaseName-codedx" 1	
}

function Set-UseToolOrchestration([string] $workDir, 
	[string] $waitSeconds,
	[string] $caCertPathToolService,
	[string] $namespace, [string] $codedxNamespace,
	[string] $toolServiceUrl, [string] $toolServiceApiKey,
	[string] $codedxReleaseName,
	[string] $caCertsFilePwd,
	[string] $caCertsFileNewPwd,
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
	helm -n $codedxNamespace upgrade --values $valuesFile --reuse-values $codedxReleaseName $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to upgrade Code Dx release for tool orchestration, helm exited with code $LASTEXITCODE."
	}

	Wait-Deployment 'Helm Upgrade' $waitSeconds $codedxNamespace "$codedxReleaseName-codedx" 1
}

function Add-CertManager([string] $namespace, [string] $codeDxNamespace,
	[string] $registrationEmailAddress, [string] $stagingIssuerFile, [string] $productionIssuerFile,
	[string] $certManagerRoleFile, [string] $certManagerRoleBindingFile, [string] $httpSolverRoleBindingFile,
	[string] $waitSeconds) {

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

	helm upgrade --namespace $namespace --install --reuse-values cert-manager jetstack/cert-manager --version v0.13.0
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
	[int] $waitSeconds,
	[string] $nginxFile,
	[string] $priorityValuesFile,
	[string] $cpuLimit,
	[string] $memoryLimit) {
	
	@'
controller:
  service:
    loadBalancerIP: {0}
'@ -f $loadBalancerIP | out-file $nginxFile -Encoding ascii -Force

	Add-NginxIngress $namespace $waitSeconds $nginxFile $priorityValuesFile $cpuLimit $memoryLimit
}

function Add-NginxIngress([string] [string] $namespace,
	[int] $waitSeconds,
	[string] $valuesFile,
	[string] $priorityValuesFile,
	[string] $cpuLimit,
	[string] $memoryLimit) {

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	$priorityClassName = 'nginx'
	if (-not (Test-PriorityClass $priorityClassName)) {
		New-PriorityClass $priorityClassName 20000
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
'@ -f $priorityClassName,(Format-ResourceLimitRequest -limitMemory $memoryLimit -limitCPU $cpuLimit -indent 2) | out-file $priorityValuesFile -Encoding ascii -Force
	
	Add-HelmRepo 'stable' 'https://kubernetes-charts.storage.googleapis.com'
	Invoke-HelmSingleDeployment 'nginx-ingress' $waitTimeSeconds $namespace 'nginx' 'stable/nginx-ingress' $valuesFile 'nginx-nginx-ingress-controller' 1 $priorityValuesFile
}

function Add-DefaultPodSecurityPolicy([string] $pspFile, [string] $roleFile, [string] $roleBindingFile) {

	$psp = @'
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
'@

	$psp | out-file $pspFile -Encoding ascii -Force
	kubectl apply -f $pspFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to apply PodSecurityPolicy. kubectl exited with code $LASTEXITCODE."
	}

	$role = @'
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: psp:privileged
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - privileged
'@

	$role | out-file $roleFile -Encoding ascii -Force
	kubectl apply -f $roleFile
    	if ($LASTEXITCODE -ne 0) {
    		throw "Unable to apply PodSecurityPolicy ClusterRole. kubectl exited with code $LASTEXITCODE."
    	}

	$roleBinding = @'
kind: ClusterRoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: psp:privileged:authenticated
roleRef:
  kind: ClusterRole
  name: psp:privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:authenticated
'@

	$roleBinding | out-file $roleBindingFile -Encoding ascii -Force
	kubectl apply -f $roleBindingFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to apply default PodSecurityPolicy RoleBinding. kubectl exited with code $LASTEXITCODE."
	}
}
