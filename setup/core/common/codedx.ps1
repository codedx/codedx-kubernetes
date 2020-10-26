<#PSScriptInfo
.VERSION 1.2.0
.GUID 6b1307f7-7098-4c65-9a86-8478840ad4cd
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for the deployment of Code Dx and Code Dx Orchestration.
#>

'utils.ps1',
'k8s.ps1',
'helm.ps1',
'private.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function New-CodeDxDeploymentValuesFile([string] $codeDxDnsName,
	[int]      $codeDxTomcatPortNumber,
	[int]      $codeDxTlsTomcatPortNumber,
	[string]   $releaseName,
	[string]   $tomcatImage,
	[string]   $tomcatImagePullSecretName,
	[string]   $dbConnectionSecret,
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
	[string]   $serviceTypeCodeDx,
	[hashtable]$serviceAnnotationsCodeDx,
	[string]   $ingressControllerNamespace,
	[hashtable]$ingressAnnotations,
	[string]   $caCertsSecretName,
	[string]   $externalDbUrl,
	[string]   $samlAppName,
	[string]   $samlIdpXmlFileConfigMapName,
	[string]   $samlSecretName,
	[string]   $tlsSecretName,
	[Tuple`2[string,string]] $codeDxNodeSelector,
	[Tuple`2[string,string]] $masterDatabaseNodeSelector,
	[Tuple`2[string,string]] $subordinateDatabaseNodeSelector,
	[Tuple`2[string,string]] $codeDxNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $masterDatabaseNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $subordinateDatabaseNoScheduleExecuteToleration,
	[string]   $backupType,
	[switch]   $useSaml,
	[switch]   $ingressEnabled,
	[switch]   $ingressAssumesNginx,
	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls,
	[switch]   $skipDatabase,
	[switch]   $skipToolOrchestration,
	[string]   $toolOrchestrationNamespace,
	[string]   $toolServiceUrl,
	[string]   $toolServiceApiKeySecretName,
	[switch]   $offlineMode,
	[string]   $valuesFile) {
 
	$imagePullSecretYaml = 'codedxTomcatImagePullSecrets: []'
	if (-not ([string]::IsNullOrWhiteSpace($tomcatImagePullSecretName))) {

		$imagePullSecretYaml = @'
codedxTomcatImagePullSecrets:
- name: {0}
'@ -f $tomcatImagePullSecretName
	}

	$psp = $enablePSPs.ToString().ToLower()
	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()
	$enableDb = (-not $skipDatabase).ToString().ToLower()

	$tlsEnabled = $configureTls.ToString().ToLower()

	$ingress = $ingressEnabled.ToString().ToLower()
	$ingressNginxAssumption = $ingressAssumesNginx.ToString().ToLower()

	$ingressNamespaceSelector = ''
	$toolServiceSelector = ''
	if ($enableNetworkPolicies) {

		if ('' -ne $ingressControllerNamespace) {
			$ingressNamespaceSelector = @'
    ingressSelectors:
    - namespaceSelector:
        matchLabels:
          name: {0}
'@ -f $ingressControllerNamespace
		}

		if (-not $skipToolOrchestration) {
			$toolServiceSelector = @'
    toolService: true
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: {0}
'@ -f $toolOrchestrationNamespace
		}
	}
	
	$toolOrchestrationValues = ''
	if (-not $skipToolOrchestration) {
		$toolOrchestrationValues = @'
  - type: secret
    name: {1}
    key: {1}
  - type: values
    key: codedx-orchestration-props
    values:
    - "tws.enabled = true"
    - "tws.service-url = {0}"
'@ -f $toolServiceUrl,$toolServiceApiKeySecretName
	}

	$externalDb = ''
	if ('' -ne $externalDbUrl) {
		$externalDb = @'
  dbconnection:
    externalDbUrl: '{0}'
'@ -f $externalDbUrl
	}

	$hostBasePath = ''
	if ($useSaml) {

		$protocol = 'https'
		if (-not $tlsEnabled) {
			$protocol = 'http'
		}
		$hostBasePath = "$protocol`://$codeDxDnsName/codedx"
	}

	$codedxPodAnnotations = New-BackupAnnotation $backupType
	if ($backupType -eq 'velero-restic') {
		$codedxPodAnnotations['backup.velero.io/backup-volumes'] = 'codedx-appdata'
	}

	$primaryDbPodAnnotations = New-BackupAnnotation $backupType
	if ($backupType -eq 'velero-restic') {
		$primaryDbPodAnnotations['backup.velero.io/backup-volumes-excludes'] = 'data'
	}

	$replicaDbPodAnnotations = New-BackupAnnotation $backupType
	if ($backupType -eq 'velero-restic') {
		$replicaDbPodAnnotations['backup.velero.io/backup-volumes'] = 'backup'
		$replicaDbPodAnnotations['backup.velero.io/backup-volumes-excludes'] = 'data'
	}

	$values = @'
existingSecret: '{0}'
codedxTomcatPort: {22}
codedxTlsTomcatPort: {23}
persistence:
  size: {11}Gi
  storageClass: {17}
codedxTls:
  enabled: {5}
  secret: {6}
  certFile: {7}
  keyFile: {8}
podAnnotations: {47}
service:
  type: {24}
  annotations: {25}
ingress:
  enabled: {13}
  annotations: {20}
  assumeNginxIngressController: {27}
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
{43}
  mariadb:
    master:
      create: {4}
    slave:
      create: {4}
codedxTomcatImage: {1}
{2}
{18}
mariadb:
  enabled: {26}
  existingSecret: '{9}'
  db:
    user: ''
  master:
    persistence:
      storageClass: {17}
      size: {10}Gi
    annotations: {45}
    nodeSelector: {32}
    tolerations: {35}
{19}
  slave:
    replicas: {15}
    persistence:
      storageClass: {17}
      size: {14}Gi
      backup:
        size: {14}Gi
    annotations: {46}
    nodeSelector: {33}
    tolerations: {36}
{21}
cacertsSecret: '{29}'
codedxProps:
  internalExtra:
  - type: values
    key: codedx-offline-props
    values:
    - "codedx.offline-mode = {30}"
{44}
{28}
nodeSelectors: {31}
tolerations: {34}
authentication:
  hostBasePath: '{37}'
  saml:
    enabled: {38}
    appName: '{39}'
    samlIdpXmlFileConfigMap: '{40}'
    samlSecret: '{41}'
databaseConnectionSecret: '{42}'
'@ -f (Get-CodeDxPdSecretName $releaseName), $tomcatImage, $imagePullSecretYaml,
$psp, $networkPolicy,
$tlsEnabled, $tlsSecretName, 'tls.crt', 'tls.key',
(Get-DatabasePdSecretName $releaseName),
$dbVolumeSizeGiB, $codeDxVolumeSizeGiB, $codeDxDnsName, $ingress,
$dbSlaveVolumeSizeGiB, $dbSlaveReplicaCount, $ingressNamespaceSelector, $storageClassName,
(Format-ResourceLimitRequest -limitMemory $codeDxMemoryLimit -limitCPU $codeDxCPULimit -limitEphemeralStorage $codeDxEphemeralStorageLimit),
(Format-ResourceLimitRequest -limitMemory $dbMasterMemoryLimit -limitCPU $dbMasterCPULimit -limitEphemeralStorage $dbMasterEphemeralStorageLimit -indent 4),
(ConvertTo-YamlMap $ingressAnnotations),
(Format-ResourceLimitRequest -limitMemory $dbSlaveMemoryLimit -limitCPU $dbSlaveCPULimit -limitEphemeralStorage $dbSlaveEphemeralStorageLimit -indent 4),
$codeDxTomcatPortNumber, $codeDxTlsTomcatPortNumber,
$serviceTypeCodeDx, (ConvertTo-YamlMap $serviceAnnotationsCodeDx),
$enableDb, $ingressNginxAssumption,
$externalDb, $caCertsSecretName, $offlineMode.ToString().ToLower(),
(Format-NodeSelector $codeDxNodeSelector), (Format-NodeSelector $masterDatabaseNodeSelector), (Format-NodeSelector $subordinateDatabaseNodeSelector),
(Format-PodTolerationNoScheduleNoExecute $codeDxNoScheduleExecuteToleration), (Format-PodTolerationNoScheduleNoExecute $masterDatabaseNoScheduleExecuteToleration), (Format-PodTolerationNoScheduleNoExecute $subordinateDatabaseNoScheduleExecuteToleration),
$hostBasePath, $useSaml.tostring().tolower(), $samlAppName, $samlIdpXmlFileConfigMapName, $samlSecretName,
$dbConnectionSecret, $toolServiceSelector, $toolOrchestrationValues,
(ConvertTo-YamlMap $primaryDbPodAnnotations),
(ConvertTo-YamlMap $replicaDbPodAnnotations),
(ConvertTo-YamlMap $codedxPodAnnotations)

	$values | out-file $valuesFile -Encoding ascii -Force
	Get-ChildItem $valuesFile
}

function New-ToolOrchestrationValuesFile([string]   $codedxNamespace,
	[string]   $codedxReleaseName,
	[int]      $codeDxTomcatPortNumber,
	[int]      $codeDxTlsTomcatPortNumber,
	[int]      $numReplicas,
	[string]   $toolsImage,
	[string]   $toolsMonoImage,
	[string]   $newAnalysisImage,
	[string]   $sendResultsImage,
	[string]   $sendErrorResultsImage,
	[string]   $toolServiceImage,
	[string]   $preDeleteImageName,
	[string]   $imagePullSecretName,
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
	[string]   $toolOrchestrationExistingSecret,
	[string]   $minioExistingSecretName,

	[string]   $tlsToolServiceCertSecret,
	[string]   $codedxCaConfigMap,

	[string]   $tlsMinioCertSecret,
	[string]   $minioCertConfigMap,

	[Tuple`2[string,string]] $toolServiceNodeSelector,
	[Tuple`2[string,string]] $minioNodeSelector,
	[Tuple`2[string,string]] $workflowControllerNodeSelector,
	[Tuple`2[string,string]] $toolNodeSelector,
	[Tuple`2[string,string]] $toolServiceNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $minioNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $workflowControllerNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $toolNoScheduleExecuteToleration,

	[string]   $backupType,

	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls,
	[string]   $valuesFile) {

	$protocol = 'http'
	$codedxPort = $codeDxTomcatPortNumber
	$tlsConfig = $configureTls.ToString().ToLower()
	
	if ($configureTls) {
		$protocol = 'https'
		$codedxPort = $codeDxTlsTomcatPortNumber
	}
	$codeDxOrchestrationFullName = Get-CodeDxChartFullName $codedxReleaseName
	$codedxBaseUrl = '{0}://{1}.{2}.svc.cluster.local:{3}/codedx' -f $protocol,$codeDxOrchestrationFullName,$codedxNamespace,$codedxPort

	$imagePullSecretYaml = 'toolServiceImagePullSecrets: []'
	if (-not ([string]::IsNullOrWhiteSpace($imagePullSecretName))) {

		$imagePullSecretYaml = @'
toolServiceImagePullSecrets:
- name: {0}
'@ -f $imagePullSecretName
	}

	$psp = $enablePSPs.ToString().ToLower()
	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()

	$minioPodAnnotations = New-BackupAnnotation $backupType
	if ($backupType -eq 'velero-restic') {
		$minioPodAnnotations['backup.velero.io/backup-volumes'] = 'data'
	}

	$values = @'
argo:
  installCRD: false
  controller:
    nodeSelector: {31}
    tolerations: {34}
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
  podAnnotations: {39}
  nodeSelector: {30}
  tolerations: {33}
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
nodeSelectors: {29}
tolerations: {32}

tools:
  nodeSelectorKey: '{35}'
  nodeSelectorValue: '{36}'
  tolerationKey: '{37}'
  tolerationValue: '{38}'
'@ -f $minioExistingSecretName,
$codedxNamespace,$codedxReleaseName,$toolOrchestrationExistingSecret,
$imagePullSecretName,$toolsImage,$toolsMonoImage,$newAnalysisImage,$sendResultsImage,$sendErrorResultsImage,$toolServiceImage,$numReplicas,
$tlsConfig,$tlsMinioCertSecret,$tlsToolServiceCertSecret,
$psp,$networkPolicy,$codedxBaseUrl,
$tlsConfig,$codedxCaConfigMap,$minioVolumeSizeGiB,$imagePullSecretYaml,$preDeleteImageName,$storageClassName, $kubeApiTargetPort,
(Format-ResourceLimitRequest -limitMemory $toolServiceMemoryLimit -limitCPU $toolServiceCPULimit -limitEphemeralStorage $toolServiceEphemeralStorageLimit),
(Format-ResourceLimitRequest -limitMemory $workflowMemoryLimit -limitCPU $workflowCPULimit -limitEphemeralStorage $workflowEphemeralStorageLimit -indent 4),
(Format-ResourceLimitRequest -limitMemory $minioMemoryLimit -limitCPU $minioCPULimit -limitEphemeralStorage $minioEphemeralStorageLimit -indent 2),
$minioCertConfigMap,
(Format-NodeSelector $toolServiceNodeSelector), (Format-NodeSelector $minioNodeSelector), (Format-NodeSelector $workflowControllerNodeSelector),
(Format-PodTolerationNoScheduleNoExecute $toolServiceNoScheduleExecuteToleration), (Format-PodTolerationNoScheduleNoExecute $minioNoScheduleExecuteToleration), (Format-PodTolerationNoScheduleNoExecute $workflowControllerNoScheduleExecuteToleration),
($null -eq $toolNodeSelector ? '' : $toolNodeSelector.Item1),
($null -eq $toolNodeSelector ? '' : $toolNodeSelector.Item2),
($null -eq $toolNoScheduleExecuteToleration ? '' : $toolNoScheduleExecuteToleration.Item1),
($null -eq $toolNoScheduleExecuteToleration ? '' : $toolNoScheduleExecuteToleration.Item2),
(ConvertTo-YamlMap $minioPodAnnotations)

	$values | out-file $valuesFile -Encoding ascii -Force
	Get-ChildItem $valuesFile
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

function Get-CodeDxKeystore([string] $namespace, [string] $imageCodeDxTomcat, [int] $waitSeconds, [string] $outPath) {

	$podName = 'copy-cacerts'

	Write-Verbose "Starting pod in $namespace using Docker image $imageCodeDxTomcat..."
	Remove-Pod $namespace $podName -force
	kubectl -n $namespace run $podName --image=$imageCodeDxTomcat --restart=Never -- sleep "$($waitSeconds)s"
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to start Code Dx pod to fetch cacerts file, kubectl exited with code $LASTEXITCODE."
	}
	Wait-RunningPod 'copy-cacerts' $waitTimeSeconds $namespace $podName

	Write-Verbose "Copying cacerts from $podName to $outPath..."
	kubectl -n $namespace cp $podName`:/usr/local/openjdk-8/jre/lib/security/cacerts $outPath
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to copy cacerts file from $podName to $outPath, kubectl exited with code $LASTEXITCODE."
	}

	Write-Verbose "Deleting pod $podName..."
	Remove-Pod $namespace $podName -force

	Get-ChildItem $outPath
}

function Add-LetsEncryptCertManagerCRDs([switch] $dryRun) {

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''
	kubectl apply --validate=false -f https://raw.githubusercontent.com/jetstack/cert-manager/v0.13.0/deploy/manifests/00-crds.yaml -o $output $dryRunParam
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add cert-manager CRDs, helm exited with code $LASTEXITCODE."
	}
}

function New-LetsEncryptCertManagerClusterIssuerFiles([string] $name,
	[string] $registrationEmailAddress,
	[string] $clusterIssuerFile,
	[switch] $useStaging) {

	$endpoint = $useStaging ? 'https://acme-staging-v02.api.letsencrypt.org/directory' : 'https://acme-v02.api.letsencrypt.org/directory'

	@'
apiVersion: cert-manager.io/v1alpha2
kind: ClusterIssuer
metadata:
  name: {1}
spec:
  acme:
    server: {2}
    email: {0}
    privateKeySecretRef:
      name: {1}
    solvers:
    - http01:
        ingress:
          class: nginx
'@ -f $registrationEmailAddress,$name,$endpoint | out-file $clusterIssuerFile -Encoding ascii -Force

	Get-ChildItem $clusterIssuerFile
}

function New-NginxIngressLoadBalancerIPValuesFile([string] $loadBalancerIP, [string] $nginxFile) {

	@'
controller:
  service:
    loadBalancerIP: {0}
'@ -f $loadBalancerIP | out-file $nginxFile -Encoding ascii -Force

	Get-ChildItem $nginxFile
}

function New-NginxIngressValuesFile([string] $cpuLimit,
	[string] $memoryLimit,
	[string] $ephemeralStorageLimit,
	[switch] $enablePSPs,
	[string] $ingressValuesFile) {

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
'@ -f $priorityClassName,(Format-ResourceLimitRequest -limitMemory $memoryLimit -limitCPU $cpuLimit -limitEphemeralStorage $ephemeralStorageLimit -indent 2),$usePSP | out-file $ingressValuesFile -Encoding ascii -Force
	
	Get-ChildItem $ingressValuesFile
}

function New-LetsEncryptValuesFile([switch] $podSecurityPolicyEnabled,
	[string] $letsEncryptValuesFile) {

	@'
global:
  podSecurityPolicy:
    enabled: {0}
'@ -f $podSecurityPolicyEnabled.ToString().ToLower() | out-file $letsEncryptValuesFile -Encoding ascii -Force
	
	Get-ChildItem $letsEncryptValuesFile
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

function Get-TrustedCaCertsFilePwd([string] $cacertsFilePath, [string] $currentPwd, [string] $newPwd) {

	if (Test-KeystorePassword $cacertsFilePath $currentPwd) {
		return $currentPwd
	}
	if (Test-KeystorePassword $cacertsFilePath $newPwd) {
		return $newPwd
	}
	'changeit' # assume default Java keystore password
}

function New-TrustedCaCertsFile([string] $basePath,
	[string]   $currentPwd, [string] $newPwd,
	[string[]] $certPathsToImport) {

	$filePath = "./cacerts"
	if (Test-Path $filePath) {
		Remove-Item $filePath -force
	}
	Copy-Item -LiteralPath $basePath -Destination $filePath

	$keystorePwd = (Get-TrustedCaCertsFilePwd $filePath $currentPwd $newPwd)

	if ('' -ne $newPwd -and $currentPwd -ne $newPwd) {
		Set-KeystorePassword $filePath $currentPwd $newPwd
		$keystorePwd = $newPwd
	}

	Import-TrustedCaCerts $filePath $keystorePwd $certPathsToImport
}

function New-SamlConfigPropsFile([string] $samlKeystorePwd,
	[string] $samlPrivateKeyPwd,
	[string] $samlPropsFile) {

	@"
auth.saml2.keystorePassword = $samlKeystorePwd
auth.saml2.privateKeyPassword = $samlPrivateKeyPwd
"@ | out-file $samlPropsFile -Encoding ascii -Force

	Get-ChildItem $samlPropsFile
}

function New-DatabaseConfigPropsFile([string] $namespace,
	[string] $databaseConnectionSecretName,
	[string] $databaseUsername,
	[string] $databasePwd,
	[string] $dbConnectionFile) {

	@"
swa.db.user = $databaseUsername
swa.db.password = $databasePwd
"@ | out-file $dbConnectionFile -Encoding ascii -Force

	Get-ChildItem $dbConnectionFile
}

function New-BackupAnnotation([string] $backupType) {

	@{'backup.codedx.io/type' = $backupType}
}