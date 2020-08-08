<#PSScriptInfo
.VERSION 1.0.0
.GUID c191448b-25fd-4ec2-980e-e7a8ba85e693
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes support for testing Code Dx prerequisites.

Note: Do not use PowerShell Core v7 syntax in this file because
it will interfere with the PowerShell Core v7 prereq check.
#>

'utils.ps1',
'helm.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Test-SetupPreqs([ref] $messages) {

	$messages.Value = @()
	$isCore = Test-IsCore
	if (-not $isCore) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
	}
	
	if ($isCore -and -not (Test-MinPsMajorVersion 7)) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core 7 or later'
	}
	
	'helm','kubectl','openssl','git','keytool' | foreach-object {
		$found = $null -ne (Get-AppCommandPath $_)
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
	$messages.Value.count -eq 0
}