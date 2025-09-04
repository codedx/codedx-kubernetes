param (
	[Parameter(Mandatory=$true)][string] $codeDxVersion,
	[Parameter(Mandatory=$true)][string] $mariaDBVersion,
	[Parameter(Mandatory=$true)][string] $toolOrchestrationVersion,
	[Parameter(Mandatory=$true)][string] $workflowVersion,
	[Parameter(Mandatory=$true)][string] $restoreDBVersion
)

$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
Set-PSDebug -Strict

Write-Verbose 'Switching to script directory...'
Push-Location (Join-Path $PSScriptRoot '..')

. ./.version/common.ps1

$setupScriptPath = './setup/core/setup.ps1'
$restoreDBPath   = './admin/restore-db.ps1'

Write-Verbose 'Testing whether update is required...'
if (Test-CodeDxVersion $setupScriptPath `
	$restoreDBPath `
	$codeDxVersion `
	$mariaDBVersion `
	$toolOrchestrationVersion `
	$workflowVersion `
	$restoreDBVersion) {
	throw 'Neither the Code Dx nor Tool Orchestration charts require an update'
}

if (-not (Test-CodeDxChartVersion $setupScriptPath $codeDxVersion)) {

	Write-Verbose 'Updating Code Dx chart version...'
	$codeDxChartDirectory = './setup/core/charts/codedx'
	Set-HelmChartVersion "$codeDxChartDirectory/Chart.yaml" $codeDxVersion

	Write-Verbose 'Updating Code Dx chart values...'
	Set-ChartDockerImageValues "$codeDxChartDirectory/values.yaml" `
		([Tuple`3[string,string,string]]::new('codedxTomcatImage',     'codedx/codedx-tomcat', $codeDxVersion),
		 [Tuple`3[string,string,string]]::new('codedxTomcatInitImage', 'codedx/codedx-tomcat', $codeDxVersion))
}

if (-not (Test-ToolOrchestrationChartVersion $setupScriptPath $codeDxVersion $toolOrchestrationVersion)) {

	Write-Verbose 'Updating Code Tool Orchestration chart version...'
	$toolOrchestrationDirectory = './setup/core/charts/codedx-tool-orchestration'
	Set-HelmChartVersion "$toolOrchestrationDirectory/Chart.yaml" $toolOrchestrationVersion
	
	Write-Verbose 'Updating Code Tool Orchestration chart values...'
	Set-ChartDockerImageValues "$toolOrchestrationDirectory/values.yaml" `
		([Tuple`3[string,string,string]]::new('imageNameCodeDxTools',      'codedx/codedx-tools',         $codeDxVersion),
		 [Tuple`3[string,string,string]]::new('imageNameCodeDxToolsMono',  'codedx/codedx-toolsmono',     $codeDxVersion),
		 [Tuple`3[string,string,string]]::new('imageNamePrepare',          'codedx/codedx-prepare',       $toolOrchestrationVersion),
		 [Tuple`3[string,string,string]]::new('imageNameNewAnalysis',      'codedx/codedx-newanalysis',   $toolOrchestrationVersion),
		 [Tuple`3[string,string,string]]::new('imageNameSendResults',      'codedx/codedx-results',       $toolOrchestrationVersion),
		 [Tuple`3[string,string,string]]::new('imageNameSendErrorResults', 'codedx/codedx-error-results', $toolOrchestrationVersion),
		 [Tuple`3[string,string,string]]::new('imageNameHelmPreDelete',    'codedx/codedx-cleanup',       $toolOrchestrationVersion),
		 [Tuple`3[string,string,string]]::new('toolServiceImageName',      'codedx/codedx-tool-service',  $toolOrchestrationVersion))
}

Write-Verbose 'Updating setup script...'
Set-ScriptDockerImageTags $setupScriptPath `
	([Tuple`3[string,string,string]]::new('imageCodeDxTomcat',       'codedx/codedx-tomcat',              $codeDxVersion),
	 [Tuple`3[string,string,string]]::new('imageCodeDxTomcatInit',   'codedx/codedx-tomcat',              $codeDxVersion),
	 [Tuple`3[string,string,string]]::new('imageMariaDB',            'codedx/codedx-mariadb',             $mariaDBVersion),
	 [Tuple`3[string,string,string]]::new('imagePrepare',            'codedx/codedx-prepare',             $toolOrchestrationVersion),
	 [Tuple`3[string,string,string]]::new('imageNewAnalysis',        'codedx/codedx-newanalysis',         $toolOrchestrationVersion),
	 [Tuple`3[string,string,string]]::new('imageSendResults',        'codedx/codedx-results',             $toolOrchestrationVersion),
	 [Tuple`3[string,string,string]]::new('imageSendErrorResults',   'codedx/codedx-error-results',       $toolOrchestrationVersion),
	 [Tuple`3[string,string,string]]::new('imageToolService',        'codedx/codedx-tool-service',        $toolOrchestrationVersion),
	 [Tuple`3[string,string,string]]::new('imagePreDelete',          'codedx/codedx-cleanup',             $toolOrchestrationVersion),
	 [Tuple`3[string,string,string]]::new('imageWorkflowController', 'codedx/codedx-workflow-controller', $workflowVersion),
	 [Tuple`3[string,string,string]]::new('imageWorkflowExecutor',   'codedx/codedx-argoexec',            $workflowVersion))

Write-Verbose 'Updating restore script...'
Set-ScriptDockerImageTags $restoreDBPath `
	([Tuple`3[string,string,string]]::new('imageDatabaseRestore',    'codedx/codedx-dbrestore',           $restoreDBVersion))
