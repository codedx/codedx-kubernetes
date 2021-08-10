<#PSScriptInfo
.VERSION 1.1.0
.GUID 031ba6fc-042c-4c0d-853c-52afb79ce7ea
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for Helm-related tasks.
#>

'k8s.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Get-HelmReleaseAppVersion([string] $namespace, [string] $releaseName) {

	$history = helm -n $namespace history $releaseName --max 1 -o json
	if ($null -eq $history) {
		return $null
	}

	$historyJson = convertfrom-json $history
	new-object Management.Automation.SemanticVersion($historyJson.app_version)
}

function Add-HelmRepo([string] $name, [string] $url) {

	helm repo add $name $url
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add helm repository, helm exited with code $LASTEXITCODE."
	}

	helm repo update
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm repo update, helm exited with code $LASTEXITCODE."
	}
}

function Test-HelmRelease([string] $namespace, [string] $releaseName) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	helm -n $namespace status $releaseName *>&1 | Out-Null
	$LASTEXITCODE -eq 0
}

function Get-HelmValues([string] $namespace, [string] $releaseName) {

	$values = helm -n $namespace get values $releaseName -o json
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get release values, helm exited with code $LASTEXITCODE."
	}
	ConvertFrom-Json $values
}

function Invoke-HelmSingleDeployment([string] $message, 
	[int]      $waitSeconds, 
	[string]   $namespace, 
	[string]   $releaseName, 
	[string]   $chartReference, 
	[string]   $valuesFile, 
	[string]   $deploymentName, 
	[int]      $totalReplicas, 
	[string[]] $extraValuesPaths, 
	[string]   $version, 
	[switch]   $reuseValues,
	[switch]   $dryRun) {

	if (-not $dryRun) {
		if (-not (Test-Namespace $namespace)) {
			New-Namespace  $namespace
		}
	}

	if (test-path $chartReference -pathtype container) {
		helm dependency update $chartReference
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to run dependency update, helm exited with code $LASTEXITCODE."
		}
	}

	if (-not $dryRun) {
		Wait-AllRunningPods "Pre-Helm Install: $message" $waitSeconds $namespace
	}
	
	# NOTE: Latter values files take precedence over former ones
	$valuesPaths = $extraValuesPaths
	if ($valuesFile -ne '') {
		$valuesPaths = @($valuesFile) + $extraValuesPaths
	}

	$values = @()
	$tmpPaths = @()
	try {
		$valuesPaths | ForEach-Object {
			$values = $values + "--values"
			$valuesFilePath = Set-KubectlFromFilePath $_ ([ref]$tmpPaths)
			$values = $values + ('"{0}"' -f $valuesFilePath)
		}

		$versionParam = @()
		if ('' -ne $version) {
			$versionParam = $versionParam + "--version"
			$versionParam = $versionParam + "$version"
		}
		
		Write-Verbose "Running Helm Upgrade: $message..."

		$dryRunParam = $dryRun ? '--dry-run' : ''
		$debugParam = $dryRun ? '--debug' : ''

		$valuesParam = '--reset-values' # merge $values with the latest, default chart values
		if ($reuseValues) {
			$valuesParam = '--reuse-values' # merge $values used with the last upgrade
		}

		helm upgrade --namespace $namespace --install $valuesParam $releaseName @($values) $chartReference @($versionParam) $dryRunParam $debugParam
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to run helm upgrade/install, helm exited with code $LASTEXITCODE."
		}
	} finally {
		$tmpPaths | ForEach-Object { Write-Verbose "Removing temporary file '$_'"; Remove-Item $_ -Force }
	}

	if (-not $dryRun) {
		Wait-Deployment "Helm Upgrade/Install: $message" $waitSeconds $namespace $deploymentName $totalReplicas
	}
}
