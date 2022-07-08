<#PSScriptInfo
.VERSION 2.0.0
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

function Split-DockerName([string] $dockerImageName, [switch] $name) {

	if (-not ($dockerImageName -match '^(?<name>.+):(?<tag>[^:]+)$')) {
		throw "Unable to find Docker image name and tag in $dockerImageName"
	}
	($matches[$name ? 'name' : 'tag']).trim()
}

function Split-DockerRepo([string] $dockerName, [switch] $repo) {

	$domain = 'docker.io'
	$name = $dockerName

	$i = $dockerName.IndexOf('/')
	if ($i -ne -1) {
		$str = $dockerName.Substring(0, $i)
		if ($str.Contains('.') -or $str.Contains(':')) {
			$domain = $str
			$name = $dockerName.Substring($i+1)
		}
	}
	return $repo ? $domain : $name
}

function Get-DockerImageParts([string] $dockerImageName) {

	$repo      = Split-DockerRepo $dockerImageName -repo
	$remainder = Split-DockerRepo $dockerImageName
	$name      = Split-DockerName $remainder -name
	$tag       = Split-DockerName $remainder

	@($repo, $name, $tag)
}

function New-CodeDxDeploymentValuesFile([string] $codeDxDnsName,
	[int]      $codeDxTomcatPortNumber,
	[int]      $codeDxTlsTomcatPortNumber,
	[string]   $releaseName,
	[string]   $tomcatImage,
	[string]   $tomcatInitImage,
	[string]   $mariaDbImage,
	[string]   $imagePullSecretName,
	[string]   $dbConnectionSecret,
	[int]      $dbVolumeSizeGiB,
	[int]      $dbSlaveReplicaCount,
	[int]      $dbSlaveVolumeSizeGiB,
	[int]      $codeDxVolumeSizeGiB,
	[string]   $appDataStorageClassName,
	[string]   $dbStorageClassName,
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
	[string]   $ingressClassName,
	[string]   $ingressTlsSecretName,
	[hashtable]$ingressAnnotations,
	[string]   $caCertsSecretName,
	[string]   $externalDbUrl,
	[string]   $samlAppName,
	[string]   $samlIdpXmlFileConfigMapName,
	[string]   $samlSecretName,
	[string]   $tlsSecretName,
	[string]   $dbMasterTlsSecretName,
	[string]   $dbMasterTlsCaConfigMapName,
	[Tuple`2[string,string]] $codeDxNodeSelector,
	[Tuple`2[string,string]] $masterDatabaseNodeSelector,
	[Tuple`2[string,string]] $subordinateDatabaseNodeSelector,
	[Tuple`2[string,string]] $codeDxNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $masterDatabaseNoScheduleExecuteToleration,
	[Tuple`2[string,string]] $subordinateDatabaseNoScheduleExecuteToleration,
	[string]   $backupType,
	[switch]   $useSaml,
	[switch]   $ingressEnabled,
	[switch]   $enablePSPs,
	[switch]   $enableNetworkPolicies,
	[switch]   $configureTls,
	[switch]   $configureServiceTls,
	[switch]   $skipDatabase,
	[int]      $proxyPort,
	[switch]   $skipToolOrchestration,
	[string]   $toolOrchestrationNamespace,
	[string]   $toolServiceUrl,
	[string]   $toolServiceApiKeySecretName,
	[switch]   $offlineMode,
	[string]   $valuesFile,
	[switch]   $createSCCs,
	[switch]   $useCodeDxDbUser) {

	$imagePullSecretYaml   = $imagePullSecretName -eq '' ? '[]' : "[ {name: '$imagePullSecretName'} ]"
	$mariaDbPullSecretYaml = $imagePullSecretName -eq '' ? '[]' : "[ '$imagePullSecretName' ]"

	$psp = $enablePSPs.ToString().ToLower()
	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()
	$enableDb = (-not $skipDatabase).ToString().ToLower()

	$tlsEnabled = $configureTls.ToString().ToLower()
	$tlsServiceEnabled = $configureServiceTls.ToString().ToLower()

	$ingress = $ingressEnabled.ToString().ToLower()

	$toolServiceSelector = ''
	if ($enableNetworkPolicies -and -not $skipToolOrchestration) {
		$toolServiceSelector = @'
    toolService: true
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: {0}
'@ -f $toolOrchestrationNamespace
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
		if (-not $ingressEnabled -and -not $tlsServiceEnabled) { # ingress will always use TLS
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


	$masterDatabaseTlsConfig = ''
	if ('' -ne $dbMasterTlsSecretName) {
		$masterDatabaseTlsConfig = @'
      ssl_cert=/bitnami/mariadb/tls/cert/tls.crt
      ssl_key=/bitnami/mariadb/tls/cert/tls.key
'@
	}

	$masterDatabaseTlsCaConfig = ''
	if ('' -ne $dbMasterTlsCaConfigMapName) {
		$masterDatabaseTlsCaConfig = @'
      ssl_ca=/bitnami/mariadb/tls/ca/ca.crt
'@
	}

	$mariaDbDockerImageParts = Get-DockerImageParts $mariaDbImage

	$grantScript = @'
      DELIMITER ^
      BEGIN NOT ATOMIC
        SELECT count(*) INTO @hasUser FROM mysql.user WHERE user='codedx';
        IF @hasUser = 1 THEN
          # Drop default privileges granted to user
          REVOKE ALL PRIVILEGES, GRANT OPTION FROM 'codedx';
          # Grant privileges required for codedx database user
          GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, CREATE TEMPORARY TABLES, ALTER, REFERENCES, INDEX, DROP, TRIGGER ON codedx.* to 'codedx'@'%';
          FLUSH PRIVILEGES;
        END IF;
      END^
'@

	$codeDxDbUserConfig = "    user: ''"
	if ($useCodeDxDbUser) {
		$codeDxDbUserConfig = @"
    user: 'codedx'
    name: 'codedx'
  initdbScripts:
    runalways-setup.sql: |
$grantScript
"@
	}

	$values = @'
existingSecret: '{0}'
codedxTomcatPort: {22}
codedxTlsTomcatPort: {23}
persistence:
  size: {11}Gi
  storageClass: {17}
codedxTls:
  componentEnabled: {5}
  serviceEnabled: {61}
  secret: {6}
  certFile: {7}
  keyFile: {8}
podAnnotations: {47}
service:
  type: '{24}'
  annotations: {25}
ingress:
  enabled: {13}
  className: {62}
  annotations: {20}
{27}
  hosts:
  - name: '{12}'
    tls: true
    tlsSecret: {63}
podSecurityPolicy:
  codedx:
    create: {3}
    bind: {3}
  mariadb:
    create: {3}
    bind: {3}
networkPolicy:
  codedx:
    create: {4}
    ldap: {4}
    ldaps: {4}
    http: {4}
    https: {4}
    proxyPort:{60}
{16}
{43}
  mariadb:
    master:
      create: {4}
    slave:
      create: {4}
codedxTomcatImage: {1}
codedxTomcatInitImage: {54}
codedxTomcatImagePullSecrets: {2}
{18}
mariadb:
  image:
    registry: {55}
    repository: {56}
    tag: {57}
    pullPolicy: Always
    pullSecrets: {58}
  enabled: {26}
  existingSecret: '{9}'
  db:
{59}
  master:
    masterTlsSecret: {48}
    masterCaConfigMap: {49}
    persistence:
      storageClass: {52}
      size: {10}Gi
    config: |-
      [mysqld]
      skip-name-resolve
      explicit_defaults_for_timestamp
      basedir=/opt/bitnami/mariadb
      port=3306
      socket=/opt/bitnami/mariadb/tmp/mysql.sock
      tmpdir=/opt/bitnami/mariadb/tmp
      max_allowed_packet=16M
      bind-address=0.0.0.0
      pid-file=/opt/bitnami/mariadb/tmp/mysqld.pid
      log-error=/opt/bitnami/mariadb/logs/mysqld.log
      character-set-server=utf8mb4
      collation-server=utf8mb4_general_ci
      optimizer_search_depth=0
      lower_case_table_names=1
      innodb_flush_log_at_trx_commit=0
      log_bin_trust_function_creators=1
{50}
{51}

      [client]
      port=3306
      socket=/opt/bitnami/mariadb/tmp/mysql.sock

      [manager]
      port=3306
      socket=/opt/bitnami/mariadb/tmp/mysql.sock
      pid-file=/opt/bitnami/mariadb/tmp/mysqld.pid
    annotations: {45}
    nodeSelector: {32}
    tolerations: {35}
{19}
  slave:
    replicas: {15}
    persistence:
      storageClass: {52}
      size: {14}Gi
      backup:
        size: {14}Gi
    config: |-
      [mysqld]
      skip-name-resolve
      explicit_defaults_for_timestamp
      basedir=/opt/bitnami/mariadb
      port=3306
      socket=/opt/bitnami/mariadb/tmp/mysql.sock
      tmpdir=/opt/bitnami/mariadb/tmp
      max_allowed_packet=16M
      bind-address=0.0.0.0
      pid-file=/opt/bitnami/mariadb/tmp/mysqld.pid
      log-error=/opt/bitnami/mariadb/logs/mysqld.log
      character-set-server=utf8mb4
      collation-server=utf8mb4_general_ci
      optimizer_search_depth=0
      lower_case_table_names=1
      innodb_flush_log_at_trx_commit=0
      log_bin_trust_function_creators=1

      [client]
      port=3306
      socket=/opt/bitnami/mariadb/tmp/mysql.sock
{51}

      [manager]
      port=3306
      socket=/opt/bitnami/mariadb/tmp/mysql.sock
      pid-file=/opt/bitnami/mariadb/tmp/mysqld.pid
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

openshift:
  createSCC: {53}
'@ -f (Get-CodeDxPdSecretName $releaseName), $tomcatImage, $imagePullSecretYaml,
$psp, $networkPolicy,
$tlsEnabled, $tlsSecretName, 'tls.crt', 'tls.key',
(Get-DatabasePdSecretName $releaseName),
$dbVolumeSizeGiB, $codeDxVolumeSizeGiB, $codeDxDnsName, $ingress,
$dbSlaveVolumeSizeGiB, $dbSlaveReplicaCount, '', $appDataStorageClassName,
(Format-ResourceLimitRequest -limitMemory $codeDxMemoryLimit -limitCPU $codeDxCPULimit -limitEphemeralStorage $codeDxEphemeralStorageLimit),
(Format-ResourceLimitRequest -limitMemory $dbMasterMemoryLimit -limitCPU $dbMasterCPULimit -limitEphemeralStorage $dbMasterEphemeralStorageLimit -indent 4),
(ConvertTo-YamlMap $ingressAnnotations),
(Format-ResourceLimitRequest -limitMemory $dbSlaveMemoryLimit -limitCPU $dbSlaveCPULimit -limitEphemeralStorage $dbSlaveEphemeralStorageLimit -indent 4),
$codeDxTomcatPortNumber, $codeDxTlsTomcatPortNumber,
$serviceTypeCodeDx, (ConvertTo-YamlMap $serviceAnnotationsCodeDx),
$enableDb, '',
$externalDb, $caCertsSecretName, $offlineMode.ToString().ToLower(),
(Format-NodeSelector $codeDxNodeSelector), (Format-NodeSelector $masterDatabaseNodeSelector), (Format-NodeSelector $subordinateDatabaseNodeSelector),
(Format-PodTolerationNoScheduleNoExecute $codeDxNoScheduleExecuteToleration), (Format-PodTolerationNoScheduleNoExecute $masterDatabaseNoScheduleExecuteToleration), (Format-PodTolerationNoScheduleNoExecute $subordinateDatabaseNoScheduleExecuteToleration),
$hostBasePath, $useSaml.tostring().tolower(), $samlAppName, $samlIdpXmlFileConfigMapName, $samlSecretName,
$dbConnectionSecret, $toolServiceSelector, $toolOrchestrationValues,
(ConvertTo-YamlMap $primaryDbPodAnnotations),
(ConvertTo-YamlMap $replicaDbPodAnnotations),
(ConvertTo-YamlMap $codedxPodAnnotations),
$dbMasterTlsSecretName, $dbMasterTlsCaConfigMapName,
$masterDatabaseTlsConfig, $masterDatabaseTlsCaConfig,
$dbStorageClassName,
$createSCCs.tostring().tolower(),
$tomcatInitImage,
$mariaDbDockerImageParts[0], $mariaDbDockerImageParts[1], $mariaDbDockerImageParts[2],
$mariaDbPullSecretYaml,
$codeDxDbUserConfig,
($proxyPort -ne 0 ? " $proxyPort" : ''),
$tlsServiceEnabled, $ingressClassName, $ingressTlsSecretName

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
	[string]   $prepareImage,
	[string]   $newAnalysisImage,
	[string]   $sendResultsImage,
	[string]   $sendErrorResultsImage,
	[string]   $toolServiceImage,
	[string]   $preDeleteImageName,
	[string]   $minioImageName,
	[string]   $workflowControllerImageName,
	[string]   $workflowExecutorImageName,
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
	[switch]   $configureServiceTls,
	[string]   $valuesFile,
	[switch]   $usePnsExecutor,
	[int]      $stepMinimumRunTimeSeconds,
	[switch]   $createSCCs) {

	$protocol = 'http'
	if ($configureTls) {
		$protocol = 'https'
	}

	$codedxPort = $codeDxTomcatPortNumber
	if ($configureServiceTls) {
		$codedxPort = $codeDxTlsTomcatPortNumber
	}

	$tlsConfig = $configureTls.ToString().ToLower()

	$codeDxOrchestrationFullName = Get-CodeDxChartFullName $codedxReleaseName
	$codedxBaseUrl = '{0}://{1}.{2}.svc.cluster.local:{3}/codedx' -f $protocol,$codeDxOrchestrationFullName,$codedxNamespace,$codedxPort

	$imagePullSecretYaml      = $imagePullSecretName -eq '' ? '[]' : "[ {name: '$imagePullSecretName'} ]"
	$minioImagePullSecretYaml = $imagePullSecretName -eq '' ? '[]' : "[ '$imagePullSecretName' ]"

	$psp = $enablePSPs.ToString().ToLower()
	$networkPolicy = $enableNetworkPolicies.ToString().ToLower()

	$minioPodAnnotations = New-BackupAnnotation $backupType
	if ($backupType -eq 'velero-restic') {
		$minioPodAnnotations['backup.velero.io/backup-volumes'] = 'data'
	}

	$minioDockerImageParts        = Get-DockerImageParts $minioImageName
	$workflowControllerImageParts = Get-DockerImageParts $workflowControllerImageName
	$workflowExecutorImageParts   = Get-DockerImageParts $workflowExecutorImageName

	if ($workflowControllerImageParts[0] -ne $workflowExecutorImageParts[0]) {
		throw "Unable to continue because $workflowControllerImageName must have the same domain as $workflowExecutorImageName"
	}

	if ($workflowControllerImageParts[2] -ne $workflowExecutorImageParts[2]) {
		throw "Unable to continue because $workflowControllerImageName must have the same tag as $workflowExecutorImageName"
	}

	$values = @'
argo:
  installCRD: false
  images:
    namespace: {45}
    controller: {46}
    executor: {47}
    tag: {48}
    pullSecrets: {21}
  controller:
    nodeSelector: {31}
    tolerations: {34}
    containerRuntimeExecutor: {40}
{26}

minio:
  global:
    minio:
      existingSecret: '{0}'
  image:
    registry: {42}
    repository: {43}
    tag: {44}
    pullSecrets: {49}
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
    bind: {15}
  twsWorkflows:
    create: {15}
    bind: {15}
  argo:
    create: {15}
    bind: {15}
  minio:
    create: {15}
    bind: {15}

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
imageNamePrepare: '{50}'
imageNameNewAnalysis: '{7}'
imageNameSendResults: '{8}'
imageNameSendErrorResults: '{9}'
toolServiceImageName: '{10}'
imageNameHelmPreDelete: '{22}'
toolServiceImagePullSecrets: {21}

{25}
nodeSelectors: {29}
tolerations: {32}

tools:
  nodeSelectorKey: '{35}'
  nodeSelectorValue: '{36}'
  tolerationKey: '{37}'
  tolerationValue: '{38}'

openshift:
  createSCC: {41}

minimumWorkflowStepRunTimeSeconds: {51}
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
(ConvertTo-YamlMap $minioPodAnnotations),
($usePnsExecutor ? "pns" : "docker"),
$createSCCs.tostring().tolower(),
$minioDockerImageParts[0],$minioDockerImageParts[1],$minioDockerImageParts[2],
$workflowControllerImageParts[0],$workflowControllerImageParts[1],$workflowExecutorImageParts[1],$workflowControllerImageParts[2],
$minioImagePullSecretYaml,$prepareImage,
$stepMinimumRunTimeSeconds

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

function Get-CodeDxKeystore([string] $namespace, [string] $imageCodeDxTomcat, [string] $imagePullSecretName, [int] $waitSeconds, [string] $outPath) {

	$podName = 'copy-cacerts'

	Write-Verbose "Starting pod in $namespace using Docker image $imageCodeDxTomcat..."
	Remove-Pod $namespace $podName -force

	$overrides = ''
	if ('' -ne $imagePullSecretName) {
		$overrides = "--overrides=$('{"apiVersion":"v1","spec":{"imagePullSecrets":[{"name":"' + $imagePullSecretName + '"}]}}' | convertto-json)"
	}

	kubectl -n $namespace run $podName --image=$imageCodeDxTomcat --restart=Never $overrides -- sleep "$($waitSeconds)s"
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to start Code Dx pod to fetch cacerts file, kubectl exited with code $LASTEXITCODE."
	}
	Wait-RunningPod 'copy-cacerts' $waitTimeSeconds $namespace $podName

	Write-Verbose "Copying cacerts from $podName to $outPath..."
	kubectl -n $namespace cp $podName`:/opt/java/openjdk/jre/lib/security/cacerts $outPath
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to copy cacerts file from $podName to $outPath, kubectl exited with code $LASTEXITCODE."
	}

	Write-Verbose "Deleting pod $podName..."
	Remove-Pod $namespace $podName -force

	Get-ChildItem $outPath
}

function Get-CodeDxChartFullName([string] $releaseName) {
	Get-HelmChartFullname $releaseName 'codedx'
}

function Get-CodeDxToolOrchestrationChartFullName([string] $releaseName) {
	Get-HelmChartFullname $releaseName 'codedx-tool-orchestration'
}

function Get-MariaDbChartFullName([string] $releaseName) {
	Get-HelmChartFullname $releaseName 'mariadb'
}

function Get-MinIOChartFullName([string] $releaseName) {
	Get-HelmChartFullname $releaseName 'minio'
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
# Note: This file uses the Human-Optimized Config Object Notation (HOCON) format.
auth.saml2.keystorePassword = """$samlKeystorePwd"""
auth.saml2.privateKeyPassword = """$samlPrivateKeyPwd"""
"@ | out-file $samlPropsFile -Encoding ascii -Force

	Get-ChildItem $samlPropsFile
}

function New-DatabaseConfigPropsFile([string] $namespace,
	[string] $databaseConnectionSecretName,
	[string] $databaseUsername,
	[string] $databasePwd,
	[string] $dbConnectionFile) {

	@"
# Note: This file uses the Human-Optimized Config Object Notation (HOCON) format.
swa.db.user = """$databaseUsername"""
swa.db.password = """$databasePwd"""
"@ | out-file $dbConnectionFile -Encoding ascii -Force

	Get-ChildItem $dbConnectionFile
}

function New-BackupAnnotation([string] $backupType) {

	@{'backup.codedx.io/type' = $backupType}
}

function Test-CodeDxDeployment([string] $namespace) {
	Test-DeploymentLabel $namespace 'app' 'codedx'
}