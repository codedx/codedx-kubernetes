$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
Set-PSDebug -Strict

function Set-HelmChartVersion([string] $chartPath, [string] $appVersion) {

	$chartLines = Get-Content $chartPath

	$versionPattern = '(?m)^version:\s(?<version>.+)$'

	$versionMatch = $chartLines | select-string -pattern $versionPattern
	if ($null -eq $versionMatch) {
		throw "Expected to find a version match in path $chartPath with $versionPattern"
	}

	$currentVersion = new-object Management.Automation.SemanticVersion($versionMatch.Matches.Groups[1].Value)
	$newVersion = "$($currentVersion.Major).$($currentVersion.Minor+1).$($currentVersion.Patch)"

	$chartLines = $chartLines -replace $versionPattern,"version: $newVersion"

	if ($appVersion -notmatch 'v\d+\.\d+\.\d+') {
		throw "Expected to find an appVersion number matching format v1.2.3 (not $appVersion)"
	}

	$appVersionPattern = '(?m)^appVersion:\s.+$'
	$chartLines = $chartLines -replace $appVersionPattern,"appVersion: ""$($appVersion.substring(1))"""

	Set-Content $chartPath $chartLines
}

function Set-ChartDockerImageValues([string] $valuesPath, $dockerImageValues) {

	$valuesLines = Get-Content $valuesPath

	$dockerImageValues | ForEach-Object {

		$pattern = "(?m)^$($_.Item1):\s\S+`$"

		$m = $valuesLines | select-string -pattern $pattern
		if ($null -eq $m) {
			throw "Expected to find a match in path $valuesPath with pattern $pattern"
		}

		$valuesLines = $valuesLines -replace $pattern, "$($_.Item1)`: '$($_.Item2)`:$($_.Item3)'"
	}

	Set-Content $valuesPath $valuesLines
}

function Set-ScriptDockerImageTags([string] $scriptPath, $dockerImageValues) {

	$scriptLines = Get-Content $scriptPath

	$dockerImageValues | ForEach-Object {

		$pattern = "(?m)^(?<definition>\t+\[string\]\s+)\`$$($_.Item1)(?<alignment>\s+)=\s'$($_.Item2)`:(?<version>.+)',`$"

		$m = $scriptLines | select-string -pattern $pattern
		if ($null -eq $m) {
			throw "Expected to find a match in path $scriptPath with pattern $pattern"
		}

		$scriptLines = $scriptLines -replace $pattern,"`${definition}`$$($_.Item1)`${alignment}= '$($_.Item2)`:$($_.Item3)',"
	}

	Set-Content $scriptPath $scriptLines
}

function Get-ScriptDockerImageTags([string] $scriptPath) {

	$pattern = "(?m)^\t+\[string\]\s+(?<dockerImageName>\`$image\S+)\s+=\s'[^:]+`:(?<version>.+)',`$"

	$m = (Get-Content $scriptPath) | Select-String -Pattern $pattern

	$tags = @{}
	$m | ForEach-Object {
		$tags[$_.Matches.Groups[1].Value] = $_.Matches.Groups[2].Value
	}
	$tags
}

function Test-CodeDxVersion([string] $setupScriptPath,
	[string] $restoreDBScriptPath,
	[string] $codeDxVersion,
	[string] $codeDxTomcatInitVersion,
	[string] $mariaDBVersion,
	[string] $toolOrchestrationVersion,
	[string] $workflowVersion,
	[string] $restoreDBVersion) {

	$tags = (Get-ScriptDockerImageTags $setupScriptPath) + (Get-ScriptDockerImageTags $restoreDBScriptPath)

	(Test-CodeDxChartVersionTags            $tags $codeDxVersion $codeDxTomcatInitVersion)  -and 
	(Test-ToolOrchestrationChartVersionTags $tags $codeDxVersion $toolOrchestrationVersion) -and 
	$tags['$imageMariaDB']            -eq $mariaDBVersion                                   -and 
	$tags['$imageWorkflowController'] -eq $workflowVersion                                  -and 
	$tags['$imageWorkflowExecutor']   -eq $workflowVersion                                  -and 
	$tags['$imageDatabaseRestore']    -eq $restoreDBVersion
}

function Test-CodeDxChartVersion([string] $setupScriptPath,
	[string] $codeDxVersion,
	[string] $codeDxTomcatInitVersion) {

	Test-CodeDxChartVersionTags `
		(Get-ScriptDockerImageTags $setupScriptPath) `
		$codeDxVersion `
		$codeDxTomcatInitVersion
}

function Test-ToolOrchestrationChartVersion([string] $setupScriptPath,
	[string] $codeDxVersion,
	[string] $toolOrchestrationVersion) {

	Test-ToolOrchestrationChartVersionTags `
		(Get-ScriptDockerImageTags $setupScriptPath) `
		$codeDxVersion `
		$toolOrchestrationVersion
}

function Test-CodeDxChartVersionTags($tags,
	[string] $codeDxVersion,
	[string] $codeDxTomcatInitVersion) {

	$tags['$imageCodeDxTomcat']       -eq $codeDxVersion           -and 
	$tags['$imageCodeDxTomcatInit']   -eq $codeDxTomcatInitVersion
}

function Test-ToolOrchestrationChartVersionTags($tags,
	[string] $codeDxVersion,
	[string] $toolOrchestrationVersion) {

	$tags['$imageCodeDxTools']        -eq $codeDxVersion            -and 
	$tags['$imageCodeDxToolsMono']    -eq $codeDxVersion            -and 
	$tags['$imagePrepare']            -eq $toolOrchestrationVersion -and 
	$tags['$imageNewAnalysis']        -eq $toolOrchestrationVersion -and 
	$tags['$imageSendResults']        -eq $toolOrchestrationVersion -and 
	$tags['$imageSendErrorResults']   -eq $toolOrchestrationVersion -and 
	$tags['$imageToolService']        -eq $toolOrchestrationVersion -and 
	$tags['$imagePreDelete']          -eq $toolOrchestrationVersion
}

function Set-SetupScriptChartsReference([string] $setupScriptPath,
	[string] $chartsTag) {

	$setupScriptLines = Get-Content $setupScriptPath

	$pattern = "(?m)^(?<definition>\t+\[string\]\s+)\`$codedxGitRepoBranch(?<alignment>\s+)=\s'[^']+',`$"
	$m = $setupScriptLines | select-string -pattern $pattern
	if ($null -eq $m) {
		throw "Expected to find a match in path $setupScriptPath with pattern $pattern"
	}

	$setupScriptLines = $setupScriptLines -replace $pattern,"`${definition}`$codedxGitRepoBranch`${alignment}= '$chartsTag',"

	Set-Content $setupScriptPath $setupScriptLines
}
