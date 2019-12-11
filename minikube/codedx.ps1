. (join-path $PSScriptRoot minikube.ps1)

function New-CodeDxDeployment([string] $codeDxDnsName,
    [string] $workDir, 
	[int]    $waitSeconds,
	[string] $namespace,
	[string] $releaseName,
	[string] $adminPwd,
	[string] $tomcatImage,
	[string] $tomcatImagePullSecretName,
	[string] $dockerConfigJson,
	[string] $mariadbRootPwd,
	[string] $mariadbReplicatorPwd,
	[int]    $dbVolumeSizeGiB,
	[int]    $codeDxVolumeSizeGiB,
	[switch] $enablePSPs,
	[switch] $enableNetworkPolicies,
	[switch] $configureTls) {
 
	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}
	Set-NamespaceLabel $namespace 'name' $namespace

	if ($null -ne $tomcatImagePullSecretName) {
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

		New-Certificate 'codedx-app-codedx' 'codedx-app-codedx' 'cdx-app' @($codeDxDnsName)
		New-CertificateSecret 'cdx-app' $tlsSecretName $tlsCertFile $tlsKeyFile
	}

	$values = @'
codedxAdminPassword: '{0}'
persistence:
  size: {12}Gi
codedxTls:
  enabled: {5}
  secret: {6}
  certFile: {7}
  keyFile: {8}
podSecurityPolicy:
  codedx:
    create: {3}
  mariadb:
    create: {3}
networkPolicy:
  codedx:
    create: {4}
  mariadb:
    master:
      create: {4}
      persistence:
        size: {11}Gi
    slave:
      create: {4}
      persistence:
        size: {11}Gi

codedxTomcatImage: {1}
codedxTomcatImagePullSecrets:
  - name: '{2}'
mariadb:
  rootUser:
    password: '{9}'
  replication:
    password: '{10}'
'@ -f $adminPwd, $tomcatImage, $tomcatImagePullSecretName, `
$psp, $networkPolicy, `
$tlsEnabled, $tlsSecretName, $tlsCertFile, $tlsKeyFile, `
$mariadbRootPwd, $mariadbReplicatorPwd, `
$dbVolumeSizeGiB, $codeDxVolumeSizeGiB

	$valuesFile = 'codedx-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	Invoke-HelmSingleDeployment 'Code Dx' $waitSeconds $namespace $releaseName $chartFolder $valuesFile 'codedx-app-codedx' 1
}

function New-ToolOrchestrationDeployment([string] $workDir, 
	[int]    $waitSeconds,
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
	[string] $imagePullSecretName,
	[string] $dockerConfigJson,
	[int]    $minioVolumeSizeGiB,
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

		New-Certificate 'toolsvc-codedx-tool-orchestration' 'toolsvc-codedx-tool-orchestration' $namespace @()
		New-Certificate 'toolsvc-minio' 'toolsvc-minio' $namespace @()

		New-CertificateSecret $namespace $tlsMinioCertSecret 'toolsvc-minio.pem' 'toolsvc-minio.key'
		New-CertificateConfigMap $namespace 'cdx-toolsvc-minio-cert' 'toolsvc-minio.pem'
		New-CertificateSecret $namespace $tlsToolServiceCertSecret 'toolsvc-codedx-tool-orchestration.pem' 'toolsvc-codedx-tool-orchestration.key'

		New-CertificateConfigMap $namespace $codedxCaConfigMap (Get-MinikubeCaCertPath)
	}
	$codedxBaseUrl = '{0}://{1}-codedx.{2}.svc.cluster.local:{3}/codedx' -f $protocol,$codedxReleaseName,$codedxNamespace,$codedxPort

	if ($null -ne $imagePullSecretName) {
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
    size: {21}Gi

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
  kubeApiTargetPort: 8443
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
toolServiceImagePullSecrets: 
  - name: '{5}'
'@ -f $minioUsername,`
$minioPwd,$codedxNamespace,$codedxReleaseName,$apiKey,`
$imagePullSecretName,$toolsImage,$toolsMonoImage,$newAnalysisImage,$sendResultsImage,$sendErrorResultsImage,$toolServiceImage,$numReplicas,
$tlsConfig,$tlsMinioCertSecret,$tlsToolServiceCertSecret,
$psp,$networkPolicy,$codedxBaseUrl,`
$tlsConfig,$codedxCaConfigMap,$minioVolumeSizeGiB

	$valuesFile = 'toolsvc-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx-tool-orchestration)
	Invoke-HelmSingleDeployment 'Tool Orchestration' $waitSeconds $namespace 'toolsvc' $chartFolder $valuesFile 'toolsvc-codedx-tool-orchestration' $numReplicas
}

function Set-UseToolOrchestration([string] $workDir, 
	[string] $waitSeconds,
	[string] $namespace, [string] $codedxNamespace,
	[string] $toolServiceUrl, [string] $toolServiceApiKey,
	[string] $codedxReleaseName,
	[switch] $enableNetworkPolicies,
	[switch] $configureTls) {

	# access cacerts file
	$podName = kubectl -n $codedxNamespace get pod -l app=codedx --field-selector=status.phase=Running -o name
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get for name of Code Dx pod, kubectl exited with code $LASTEXITCODE."
	}

	$podFile = "$($podName.Replace('pod/', ''))`:/etc/ssl/certs/java/cacerts"
	kubectl -n $codedxNamespace cp $podFile './cacerts'
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to copy out cacerts file, kubectl exited with code $LASTEXITCODE."
	}

	# update cacerts file
	keytool -import -trustcacerts -keystore cacerts -file (Get-MinikubeCaCertPath) -noprompt -storepass changeit
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to import CA certificate into cacerts file, keytool exited with code $LASTEXITCODE."
	}

	$chartFolder = (join-path $workDir codedx-kubernetes/codedx)
	copy-item cacerts $chartFolder -Force

	$networkPolicy = 'false'
	if ($enableNetworkPolicies) {
		$networkPolicy = 'true'
	}

	$cacertsFile = ''
	if ($configureTls) {
		$cacertsFile = 'cacerts'
	}

	$values = @'
codedxProps:
  extra:
  - type: values
    key: cdx-tool-orchestration
    values:
    - "tws.enabled = true"
    - "tws.service-url = {0}"
    - "tws.api-key = {1}"

networkPolicy:
  codedx:
    toolService: {3}
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: {2}

cacertsFile: {4}
'@ -f $toolServiceUrl, $toolServiceApiKey, $namespace, $networkPolicy, $cacertsFile

	$valuesFile = 'codedx-orchestration-values.yaml'
	$values | out-file $valuesFile -Encoding ascii -Force

	helm upgrade --values $valuesFile --reuse-values $codedxReleaseName $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to upgrade Code Dx release for tool orchestration, helm exited with code $LASTEXITCODE."
	}

	Wait-Deployment 'Helm Upgrade' $waitSeconds $codedxNamespace "$codedxReleaseName-codedx" 1
}
