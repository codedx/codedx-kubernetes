<#PSScriptInfo
.VERSION 1.4.0
.GUID c191448b-25fd-4ec2-980e-e7a8ba85e693
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes support for testing Code Dx prerequisites.

Note: Do not use PowerShell Core v7 syntax in this file because
it will interfere with the PowerShell Core v7 prereq check.
#>

'utils.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Get-KubectlVersion {

	$Local:ErrorActionPreference = 'Continue'
	$version = kubectl version -o json
	if (0 -ne $LASTEXITCODE) {
		throw "Unable to run 'kubectl version' command, kubectl exited with exit code $LASTEXITCODE. Is your environment connected to your cluster?"
	}
	$version | ConvertFrom-Json
}

function Get-KubectlContext() { # note: copied from k8s.ps1, which uses pwsh v7 syntax

	$Local:ErrorActionPreference = 'Continue'
	$contextName = kubectl config current-context
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubectl context, kubectl exited with code $LASTEXITCODE."
	}
	$contextName
}

function Set-KubectlContext([string] $contextName) { # note: copied from k8s.ps1, which uses pwsh v7 syntax

	$Local:ErrorActionPreference = 'Continue'
	kubectl config use-context $contextName *>&1 | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change kubectl context, kubectl exited with code $LASTEXITCODE."
	}
}

function Get-SemanticVersionComponents([string] $version) {

	if ($version.ToLower().StartsWith('v')) {
		$version = $version.Substring(1)
	}

	# Regular Expression from https://semver.org/
	$semanticVersionRegex = '^(0|[1-9]\d*)\.(0|[1-9]\d*)\.(0|[1-9]\d*)(?:-((?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*)(?:\.(?:0|[1-9]\d*|\d*[a-zA-Z-][0-9a-zA-Z-]*))*))?(?:\+([0-9a-zA-Z-]+(?:\.[0-9a-zA-Z-]+)*))?$'
	if (-not ($version -match $semanticVersionRegex)) {
		throw "'$version' is not a semantic version"
	}
	$matches
}

function Get-KubectlClientVersion {

	$versionInfo = Get-KubectlVersion
	$version = Get-SemanticVersionComponents $versionInfo.clientVersion.gitVersion
	"$($version[1]).$($version[2])"
}

function Get-KubectlServerSemanticVersion {

	$versionInfo = Get-KubectlVersion
	Get-SemanticVersionComponents $versionInfo.serverVersion.gitVersion
}

function Get-KubectlServerVersion {

	$version = Get-KubectlServerSemanticVersion
	"$($version[1]).$($version[2])"
}

function Get-KubectlServerVersionMajor {
	[int]::Parse(((Get-KubectlServerSemanticVersion)[1]))
}

function Get-KubectlServerVersionMinor {
	[int]::Parse(((Get-KubectlServerSemanticVersion)[2]))
}

function Get-HelmVersionMajorMinor() {

	$versionMatch = helm version -c | select-string 'Version:"v(?<version>\d+\.\d+)'
	if ($null -eq $versionMatch -or -not $versionMatch.Matches.Success) {
		return $null
	}
	[double]$versionMatch.Matches.Groups[1].Value
}

function Get-KeytoolJavaSettings() {

	$keytoolPath = Get-AppCommandPath 'keytool' | Select-Object -First 1
	if ($null -eq $keytoolPath) {
		return $null
	}

	$javaSettings = $null
	$local:ErrorActionPreference = 'Continue'

	Push-Location (Split-Path $keytoolPath)
	if ((Test-Path java -PathType Leaf) -or (Test-Path java.exe -PathType Leaf)) {
		$javaSettings = ./java -XshowSettings:all -version 2>&1
	}
	Pop-Location

	$javaSettings
}

function Get-KeytoolJavaSpec() {

	$javaSettings = Get-KeytoolJavaSettings
	if ($null -eq $javaSettings) {
		return $null
	}
	if (-not ($javaSettings | select-string  'java.vm.specification.version' | ForEach-Object { $_ -match 'java.vm.specification.version\s=\s(?<version>.+)' })) {
		return $null
	}
	$matches['version']
}

function Test-SetupKubernetesVersion([ref] $messages) {

	$messages.Value = @()
	$k8sRequiredMajorVersion = 1
	$k8sMinimumMinorVersion  = 19
	$k8sMaximumMinorVersion  = 24

	if ((Get-KubectlServerVersionMajor) -ne $k8sRequiredMajorVersion) {
		$messages.Value += "Unable to continue because the version of the selected Kubernetes cluster is unsupported (the kubectl server major version is not $k8sRequiredMajorVersion)."
	} else {
		$serverVersionMinor = Get-KubectlServerVersionMinor
		if ($serverVersionMinor -lt $k8sMinimumMinorVersion -or $serverVersionMinor -gt $k8sMaximumMinorVersion) {
			$messages.Value += "Unable to continue because the version of the selected Kubernetes cluster ($serverVersionMinor) is unsupported (the kubectl server minor version must be between $k8sMinimumMinorVersion and $k8sMaximumMinorVersion)."
		} else {
			$clientVersion = Get-KubectlClientVersion
			$serverVersion = Get-KubectlServerVersion
			if ($clientVersion -ne $serverVersion) {
				$messages.Value += "Unable to continue because the kubectl client version ($clientVersion) does not match the Kubernetes cluster version ($serverVersion)."
			}
		}
	}
	return $messages.Value.Length -eq 0
}

function Test-SetupPreqs([ref] $messages, [switch] $useSealedSecrets, [string] $context, [switch] $checkKubectlVersion) {

	$messages.Value = @()
	$isCore = Test-IsCore
	if (-not $isCore) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
	}
	
	if ($isCore -and -not (Test-MinPsMajorVersion 7)) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core 7 or later'
	}
	
	$apps = 'helm','kubectl','openssl','git','keytool'
	if ($useSealedSecrets) {
		$apps += 'kubeseal'
	}

	$appStatus = @{}
	$apps | foreach-object {
		$found = $null -ne (Get-AppCommandPath $_)
		$appStatus[$_] = $found

		if (-not $found) {
			$messages.Value += "Unable to continue because $_ cannot be found. Is $_ installed and included in your PATH?"
		}
		if ($found -and $_ -eq 'helm') {
			$helmVersion = Get-HelmVersionMajorMinor
			if ($null -eq $helmVersion) {
				$messages.Value += 'Unable to continue because helm version was not detected.'
			}
			
			$minimumHelmVersion = 3.1 # required for helm lookup function
			if ($helmVersion -lt $minimumHelmVersion) {
				$messages.Value += "Unable to continue with helm version $helmVersion, version $minimumHelmVersion or later is required"
			}
		}
	}

	$canUseKubectl = $appStatus['kubectl']
	if ($canUseKubectl -and $checkKubectlVersion) {

		if ($context -eq '') {
			$context = Get-KubectlContext
		}
		Set-KubectlContext $context

		$k8sMessages = @()
		if (-not (Test-SetupKubernetesVersion ([ref]$k8sMessages))) {
			$messages.Value += $k8sMessages
			$messages.Value += "Note: The prerequisite check used kubectl context '$context'"
		}
	}

	$keytoolJavaSpec = Get-KeytoolJavaSpec
	if ($null -eq $keytoolJavaSpec) {
		$keytoolJavaSpec = '?'
	}
	$requiredJavaSpec = '11'
	if ($requiredJavaSpec -ne $keytoolJavaSpec) {
		$messages.Value += "keytool application is associated with an unsupported java.vm.specification version ($keytoolJavaSpec), update your PATH to run the Java $requiredJavaSpec version of the keytool application"
	}

	$messages.Value.count -eq 0
}