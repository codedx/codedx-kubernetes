<#PSScriptInfo
.VERSION 1.1.0
.GUID c312e161-60ba-420b-83ae-45cdc25c12db
.AUTHOR Code Dx
.DESCRIPTION Conditionally installs guided-setup module
#>

$ErrorActionPreference = 'Stop'

Set-PSDebug -Strict

function Test-AvailableModule($name, $version) {
	$null -ne (Get-InstalledModule -Name $name -RequiredVersion $version -ErrorAction 'SilentlyContinue') -or
		$null -ne (Get-Module -ListAvailable -Name $name | Where-Object { $_.version -eq $version })
}

$guidedSetupModuleName = 'guided-setup'
$guidedSetupRequiredVersion = '1.6.0' # must match constant in using-module statements

$verbosePref = $global:VerbosePreference
try {
	$global:VerbosePreference = 'SilentlyContinue'

	$isModuleAvailable = Test-AvailableModule $guidedSetupModuleName $guidedSetupRequiredVersion

	$status = 'unavailable'
	if ($isModuleAvailable) {
		$status = 'available'
	}
	Write-Host "Version $guidedSetupRequiredVersion of the $guidedSetupModuleName module is $status"

	if (-not $isModuleAvailable) {

		Write-Host 'Displaying available module repositories...'
		Get-PSRepository | ForEach-Object {
			Write-Host " - $($_.Name) at $($_.SourceLocation) ($($_.InstallationPolicy))"
		}

		# Note: Install-Module will prompt when installing modules from an untrusted repository, so
		# adjust the installation policy in environments where an interactive experience is undesirable.
		#
		# You can adjust the installation policy for the PowerShell Gallery with this command:
		# Set-PSRepository -Name PSGallery -InstallationPolicy Trusted

		Write-Host "`nTrying to install $guidedSetupModuleName module v$guidedSetupRequiredVersion...`n"
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Install-Module -Name $guidedSetupModuleName -RequiredVersion $guidedSetupRequiredVersion -Scope CurrentUser
	}

	if (-not (Test-AvailableModule $guidedSetupModuleName $guidedSetupRequiredVersion)) {
		Write-Error "Unable to continue without version $guidedSetupRequiredVersion of the $guidedSetupModuleName module."
	}

} finally {
	$global:VerbosePreference = $verbosePref
}
