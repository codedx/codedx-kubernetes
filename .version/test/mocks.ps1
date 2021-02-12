
$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$global:fileSource = @{
	'./setup/core/setup.ps1' = @(
		'param (',
		'	[string]                 $workDir = "$HOME/.k8s-codedx",',
		'	[string]                 $kubeContextName,',
		'',
		'	[string]                 $imageCodeDxTomcat       = ''codedx/codedx-tomcat:v1.0.0'',',
		'	[string]                 $imageCodeDxTools        = ''codedx/codedx-tools:v1.0.0'',',
		'	[string]                 $imageCodeDxToolsMono    = ''codedx/codedx-toolsmono:v1.0.0'',',
		'',
		'	[string]                 $imagePrepare            = ''codedx/codedx-prepare:v1.0.1'',',
		'	[string]                 $imageNewAnalysis        = ''codedx/codedx-newanalysis:v1.0.1'',',
		'	[string]                 $imageSendResults        = ''codedx/codedx-results:v1.0.1'',',
		'	[string]                 $imageSendErrorResults   = ''codedx/codedx-error-results:v1.0.1'',',
		'	[string]                 $imageToolService        = ''codedx/codedx-tool-service:v1.0.1'',',
		'	[string]                 $imagePreDelete          = ''codedx/codedx-cleanup:v1.0.1'',',
		'',
		'	[string]                 $imageCodeDxTomcatInit   = ''codedx/codedx-bash:v1.0.2'',',
		'	[string]                 $imageMariaDB            = ''codedx/codedx-mariadb:v1.0.3'',',
		'	[string]                 $imageMinio              = ''bitnami/minio:2020.3.25-debian-10-r4'',',
		'	[string]                 $imageWorkflowController = ''codedx/codedx-workflow-controller:v1.0.4'',',
		'	[string]                 $imageWorkflowExecutor   = ''codedx/codedx-argoexec:v1.0.4'',',
		'',
		'	[int]                    $toolServiceReplicas = 3,'
	)
	'./admin/restore-db.ps1' = @(
		'param (',
		'	[string] $workDirectory = ''~'',',
		'	[string] $backupToRestore,'
		'	[string] $rootPwd,'
		'	[string] $replicationPwd,'
		'	[string] $namespaceCodeDx = ''cdx-app'','
		'	[string] $releaseNameCodeDx = ''codedx'','
		'	[int]    $waitSeconds = 600,'
		'	[string] $imageDatabaseRestore = ''codedx/codedx-dbrestore:v1.0.5'','
		'	[string] $dockerImagePullSecretName,'
		'	[switch] $skipCodeDxRestart'
		')'
		''
		'$ErrorActionPreference = ''Stop'''
		'$VerbosePreference = ''Continue'''
	)
	'./setup/core/charts/codedx/Chart.yaml' = @(
		'apiVersion: v2',
		'name: codedx',
		'version: 1.0.0',
		'appVersion: "1.0.0"',
		'description: A Helm chart for Code Dx'
	)
	'./setup/core/charts/codedx/values.yaml' = @(
		'# Default values for codedx.',
		'',
		'# codedxTomcatImage specifies the image to use for the Code Dx deployment.',
		'# ref: https://hub.docker.com/r/codedx/codedx-tomcat/tags',
		'#',
		'codedxTomcatImage: codedx/codedx-tomcat:v1.0.0',
		''
		'# codedxTomcatInitImage specifies the image to use for the Code Dx deployment initialization.',
		'# ref: https://hub.docker.com/r/codedx/codedx-bash/tags',
		'#',
		'codedxTomcatInitImage: codedx/codedx-bash:v1.0.2',
		'',
		'# codedxTomcatImagePullPolicy specifies the policy to use when pulling the Code Dx Tomcat image.',
		'# ref: https://kubernetes.io/docs/concepts/configuration/overview/#container-images',
		'#',
		'codedxTomcatImagePullPolicy: IfNotPresent'
	)
	'./setup/core/charts/codedx-tool-orchestration/Chart.yaml' = @(
		'apiVersion: v2',
		'name: codedx-tool-orchestration',
		'version: 1.0.1',
		'appVersion: "1.0.1"',
		'description: A Helm chart for Code Dx Tool Orchestration'
	)
	'./setup/core/charts/codedx-tool-orchestration/values.yaml' = @(
		'codedxTls:',
		'  enabled: false',
		'  caConfigMap: ',
		'',
		'imageNameCodeDxTools: "codedx/codedx-tools:v1.0.0"',
		'imageNameCodeDxToolsMono: "codedx/codedx-toolsmono:v1.0.0"',
		'imageNamePrepare: "codedx/codedx-prepare:v1.0.1"',
		'imageNameNewAnalysis: "codedx/codedx-newanalysis:v1.0.1"',
		'imageNameSendResults: "codedx/codedx-results:v1.0.1"',
		'imageNameSendErrorResults: "codedx/codedx-error-results:v1.0.1"',
		'imageNameHelmPreDelete: "codedx/codedx-cleanup:v1.0.1"',
		'imagePullSecretKey: ""',
		'',
		'toolServiceImageName: codedx/codedx-tool-service:v1.0.1',
		'toolServiceImagePullSecrets: []'
	)
}

$global:fileContent = @{}

$global:mocks = {

	Mock Get-Content  {
		$global:fileSource[$path]
	}

	Mock Set-Content {
		$global:fileContent[$path[0]] = $value
	}
}
