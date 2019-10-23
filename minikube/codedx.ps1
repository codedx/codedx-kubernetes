. (join-path $PSScriptRoot minikube.ps1)

function New-CodeDxDeployment([string] $workDir, 
    [string] $namespace, 
    [string] $releaseName,
    [string] $adminPwd, 
    [string] $tomcatImage, 
    [string] $tomcatImagePullSecretName) {
 
    if (-not (Test-Namespace $namespace)) {
        New-Namespace  $namespace
    }
    Set-NamespaceLabel $namespace 'name' $namespace

    if ($null -ne $tomcatImagePullSecretName) {
        New-ImagePullSecret $namespace $tomcatImagePullSecretName $dockerConfigJson
    }

    $values = @'
codedxAdminPassword: '{0}'
codedxTomcatImage: {1}
codedxTomcatImagePullSecrets:
  - name: '{2}'
'@ -f $adminPwd, $tomcatImage, $tomcatImagePullSecretName

    $valuesFile = 'codedx-values.yaml'
    $values | out-file $valuesFile -Encoding ascii -Force

    $chartFolder = (join-path $workDir codedx-kubernetes/codedx)
    Invoke-HelmSingleDeployment 'Code Dx' $namespace $releaseName $chartFolder $valuesFile 'codedx-app-codedx' 1
}

function New-ToolOrchestrationDeployment([string] $workDir, 
    [string] $namespace, 
    [string] $codedxNamespace,
    [string] $codedxReleaseName,
    [string] $minioUsername,
    [string] $minioPwd,
    [string] $apiKey,
    [string] $toolsImage,
    [string] $toolsMonoImage,
    [string] $newAnalysisImage,
    [string] $sendResultsImage,
    [string] $sendErrorResultsImage,
    [string] $toolServiceImage,
    [string] $imagePullSecretName) {

    if (-not (Test-Namespace $namespace)) {
        New-Namespace  $namespace
    }
    Set-NamespaceLabel $namespace 'name' $namespace

    New-Certificate 'toolsvc-codedx-tool-orchestration' 'toolsvc-codedx-tool-orchestration' $namespace
    New-Certificate 'toolsvc-minio' 'toolsvc-minio' $namespace

    New-CertificateSecret $namespace 'cdx-toolsvc-minio-tls' 'toolsvc-minio.pem' 'toolsvc-minio.key'
    New-CertificateConfigMap $namespace 'cdx-toolsvc-minio-cert' 'toolsvc-minio.pem'
    New-CertificateSecret $namespace 'cdx-toolsvc-codedx-tool-orchestration-tls' 'toolsvc-codedx-tool-orchestration.pem' 'toolsvc-codedx-tool-orchestration.key'

    if ($null -ne $imagePullSecretName) {
        New-ImagePullSecret $namespace $imagePullSecretName $dockerConfigJson
    }

    $values = @'
minio:
  global:
    minio:
      accessKeyGlobal: '{0}'
      secretKeyGlobal: '{1}'
    tls:
      enabled: true
      certSecret: 'cdx-toolsvc-minio-tls'
      publicCrt: 'toolsvc-minio.pem'
      privateKey: 'toolsvc-minio.key'
  
minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'
  
networkPolicy:
  kubeApiTargetPort: 8443
  codeDxSelectors:
  - namespaceSelector:
      matchLabels:
        name: '{2}'
  
codeDxBaseUrl: 'http://{3}-codedx.{2}.svc.cluster.local:9090/codedx'
  
toolServiceApiKey: '{4}'
toolServiceTls:
  secret: 'cdx-toolsvc-codedx-tool-orchestration-tls'
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
$imagePullSecretName,$toolsImage,$toolsMonoImage,$newAnalysisImage,$sendResultsImage,$sendErrorResultsImage,$toolServiceImage

    $valuesFile = 'toolsvc-values.yaml'
    $values | out-file $valuesFile -Encoding ascii -Force

    $chartFolder = (join-path $workDir codedx-kubernetes/codedx-tool-orchestration)
    Invoke-HelmSingleDeployment 'Tool Orchestration' $namespace 'toolsvc' $chartFolder $valuesFile 'toolsvc-codedx-tool-orchestration' 3
}

function Set-UseToolOrchestration([string] $workDir, 
    [string] $namespace, [string] $codedxNamespace, 
    [string] $toolServiceUrl, [string] $toolServiceApiKey, 
    [string] $codeDxReleaseName) {
    
    # access cacerts file
    # TODO: Add status=Running
    $podName = & kubectl -n $codedxNamespace get pod -l app=codedx -o name
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to get for name of Code Dx pod, kubectl exited with code $LASTEXITCODE."
    }

    $podFile = "$($podName.Replace('pod/', ''))`:/etc/ssl/certs/java/cacerts"
    & kubectl -n $codedxNamespace cp $podFile './cacerts'
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to copy out cacerts file, kubectl exited with code $LASTEXITCODE."
    }

    # update cacerts file
    & keytool -import -trustcacerts -keystore cacerts -file (Get-MinikubeCaCertPath) -noprompt -storepass changeit
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to import CA certificate into cacerts file, keytool exited with code $LASTEXITCODE."
    }

    $chartFolder = (join-path $workDir codedx-kubernetes/codedx)
    copy-item cacerts $chartFolder -Force

    $values = @'
codedxProps:
  extra:
  - type: values
    key: cdx-tool-orchestration
    values:
    - "tws.enabled = true"
    - "tws.serviceUrl = {0}"
    - "tws.apiKey = {1}"
  
networkPolicy:
  codedx:
    toolService: true
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: {2}
  
cacertsFile: 'cacerts'
'@ -f $toolServiceUrl, $toolServiceApiKey, $namespace

    $valuesFile = 'codedx-orchestration-values.yaml'
    $values | out-file $valuesFile -Encoding ascii -Force

    & helm upgrade --values $valuesFile --reuse-values $codeDxReleaseName $chartFolder 
    if ($LASTEXITCODE -ne 0) {
        throw "Unable to upgrade Code Dx release for tool orchestration, helm exited with code $LASTEXITCODE."
    }

    Wait-Deployment 'Helm Upgrade' 300 15 $codedxNamespace "$codeDxReleaseName-codedx" 1
}
