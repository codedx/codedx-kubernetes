$ErrorActionPreference = 'Stop'
$VerbosePreference     = 'Continue'
Set-PSDebug -Strict

function Set-HelmChartVersion([string] $chartPath, [string] $appVersion) {

	$chartLines = Get-Content $chartPath

	$versionPattern = '(?m)^version:\s(?<version>.+)$'

	$m = select-string -path $chartPath -pattern $versionPattern
	if ($null -eq $m) {
		throw "Expected to find a version match in path $chartPath with $versionPattern"
	}

	$v = new-object Management.Automation.SemanticVersion($m.Matches.Groups[1].Value)
	$newVersion = "$($v.Major).$($v.Minor+1).$($v.Patch)"

	$chartLines = $chartLines -replace $versionPattern,"version: $newVersion"

	$appVersionPattern = '(?m)^appVersion:\s.+$'
	$chartLines = $chartLines -replace $appVersionPattern,"appVersion: ""$appVersion"""

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

function Set-SetupScriptDockerImageTags([string] $setupScriptPath, $dockerImageValues) {

	$setupScriptLines = Get-Content $setupScriptPath

	$dockerImageValues | ForEach-Object {

		$pattern = "(?m)^(?<definition>\t+\[string\]\s+)\`$$($_.Item1)(?<alignment>\s+)=\s'$($_.Item2)`:(?<version>.+)',`$"

		$m = $setupScriptLines | select-string -pattern $pattern
		if ($null -eq $m) {
			throw "Expected to find a match in path $setupScriptPath with pattern $pattern"
		}

		$setupScriptLines = $setupScriptLines -replace $pattern,"`${definition}`$$($_.Item1)`${alignment}= '$($_.Item2)`:$($_.Item3)',"
	}

	Set-Content $setupScriptPath $setupScriptLines
}

function Get-SetupScriptDockerImageTags([string] $setupScriptPath) {

	$pattern = "(?m)^\t+\[string\]\s+(?<dockerImageName>\`$image\S+)\s+=\s'[^:]+`:(?<version>.+)',`$"

	$m = Get-Content $setupScriptPath | Select-String -Pattern $pattern

	$tags = @{}
	$m | ForEach-Object {
		$tags[$_.Matches.Groups[1].Value] = $_.Matches.Groups[2].Value
	}
	$tags
}

function Test-CodeDxVersion([string] $setupScriptPath,
	[string] $codeDxVersion,
	[string] $codeDxTomcatInitVersion,
	[string] $mariaDBVersion,
	[string] $toolOrchestrationVersion,
	[string] $workflowVersion) {

	$tags = Get-SetupScriptDockerImageTags $setupScriptPath

	$tags['$imageCodeDxTomcat']       -eq $codeDxVersion             -and 
	$tags['$imageCodeDxTools']        -eq $codeDxVersion             -and 
	$tags['$imageCodeDxToolsMono']    -eq $codeDxVersion             -and 
	$tags['$imageCodeDxTomcatInit']   -eq $codeDxTomcatInitVersion   -and 
	$tags['$imageMariaDB']            -eq $mariaDBVersion            -and 
	$tags['$imagePrepare']            -eq $toolOrchestrationVersion  -and 
	$tags['$imageNewAnalysis']        -eq $toolOrchestrationVersion  -and 
	$tags['$imageSendResults']        -eq $toolOrchestrationVersion  -and 
	$tags['$imageSendErrorResults']   -eq $toolOrchestrationVersion  -and 
	$tags['$imageToolService']        -eq $toolOrchestrationVersion  -and 
	$tags['$imagePreDelete']          -eq $toolOrchestrationVersion  -and 
	$tags['$imageWorkflowController'] -eq $workflowVersion -and 
	$tags['$imageWorkflowExecutor']   -eq $workflowVersion
}
