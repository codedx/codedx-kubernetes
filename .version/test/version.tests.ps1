
$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

Import-Module 'pester' -ErrorAction SilentlyContinue
if (-not $?) {
	Write-Host 'Pester is not installed, so this test cannot run. Run pwsh, install the Pester module (Install-Module Pester), and re-run this script.'
	exit 1
}

$location = Join-Path $PSScriptRoot '../..'
Push-Location $location

Describe 'version.ps1' {

	It 'placeholder' {

	}
}
