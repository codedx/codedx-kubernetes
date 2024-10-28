<#PSScriptInfo
.VERSION 1.8.0
.GUID c312e161-60ba-420b-83ae-45cdc25c12db
.AUTHOR Black Duck
.COPYRIGHT Copyright 2024 Black Duck Software, Inc. All rights reserved.
.DESCRIPTION Conditionally installs guided-setup module
#>

$ErrorActionPreference = 'Stop'

Set-PSDebug -Strict

# Note: This script will install a specific guided-setup module version from the PowerShell 
# Gallery (https://www.powershellgallery.com/). Here's how to install the module if you 
# prefer to download it from the PowerShell Gallery manually:
#
# 1. Browse to https://www.powershellgallery.com/packages/guided-setup/<version>, replacing 
#    <version> with the $guidedSetupRequiredVersion parameter value (see Line 33)
# 2. Click the "Manual Download" tab
# 3. Click the "Download the raw nupkg file" button
# 4. Append ".zip" to the downloaded file
# 5. Create a new directory named /path/to/modules/guided-setup (replace /path/to accordingly)
# 6. Extract the zip file to /path/to/modules/guided-setup (e.g., you'll have /path/to/modules/guided-setup/guided-setup.psd1)
# 7. Ensure read permissions for all files under /path/to/modules/guided-setup files (running "Get-Module -ListAvailable" 
#    will show guided-setup version 0.0 with insufficient privileges)
# 8. Append /path/to/modules (not /path/to/modules/guided-setup) to your PSModulePath environment variable

function Test-AvailableModule($name, $version) {
	$null -ne (Get-InstalledModule -Name $name -RequiredVersion $version -ErrorAction 'SilentlyContinue') -or
		$null -ne (Get-Module -ListAvailable -Name $name | Where-Object { $_.version -eq $version })
}

$guidedSetupModuleName = 'guided-setup'
$guidedSetupRequiredVersion = '1.14.0' # must match constant in using-module statements

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
