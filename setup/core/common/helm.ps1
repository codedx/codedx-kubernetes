<#PSScriptInfo
.VERSION 1.0.1
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

function Get-HelmVersionMajorMinor() {

	$versionMatch = helm version | select-string 'Version:"v(?<version>\d+\.\d+)'
	if ($null -eq $versionMatch -or -not $versionMatch.Matches.Success) {
		return $null
	}
	[double]$versionMatch.Matches.Groups[1].Value
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

	helm -n $namespace status $releaseName | Out-Null
	$LASTEXITCODE -eq 0
}

function Get-HelmValues([string] $namespace, [string] $releaseName) {

	$values = helm -n $namespace get values $releaseName -o json
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get release values, helm exited with code $LASTEXITCODE."
	}
	ConvertFrom-Json $values
}

function Invoke-HelmSingleDeployment([string] $message, [int] $waitSeconds, [string] $namespace, [string] $releaseName, [string] $chartReference, [string] $valuesFile, [string] $deploymentName, [int] $totalReplicas, [string[]] $extraValuesPaths) {

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}

	if (test-path $chartReference -pathtype container) {
		helm dependency update $chartReference
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to run dependency update, helm exited with code $LASTEXITCODE."
		}
	}

	Wait-AllRunningPods "Pre-Helm Install: $message" $waitSeconds $namespace

	# NOTE: Latter values files take precedence over former ones
	$valuesPaths = $extraValuesPaths
	if ($valuesFile -ne '') {
		$valuesPaths = @($valuesFile) + $extraValuesPaths
	}

	$values = @()
	$valuesPaths | ForEach-Object {
		$values = $values + "--values"
		$values = $values + ('"{0}"' -f $_)
	}

	helm upgrade --namespace $namespace --install --reuse-values $releaseName @($values) $chartReference
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm upgrade/install, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment "Helm Upgrade/Install: $message" $waitSeconds $namespace $deploymentName $totalReplicas
}
