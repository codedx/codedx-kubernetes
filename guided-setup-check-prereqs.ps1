<#PSScriptInfo
.VERSION 1.3.0
.GUID ec9b62b9-a404-4d72-bf90-92f5b1d9975f
.AUTHOR Black Duck
.COPYRIGHT Copyright 2024 Black Duck Software, Inc. All rights reserved.
#>

param (
	[switch] $gitOpsBitnamiDeploy,
	[switch] $silent
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'./.install-guided-setup-module.ps1','./setup/core/common/prereqs.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

if ($silent) {
	# avoid ternary operator that's unsupported in pwsh v6
	if ($gitOpsBitnamiDeploy) {
		$choice = 0
	} else {
		$choice = 1
	}
} else {
	$yes    = New-Object Management.Automation.Host.ChoiceDescription('&Yes', 'Yes, I plan to use Flux or Bitnami''s Sealed Secrets.')
	$no     = New-Object Management.Automation.Host.ChoiceDescription('&No',  'No, I do not plan to use Flux or Bitnami''s Sealed Secrets.')
	$choice = (Get-Host).UI.PromptForChoice('Code Dx Requirements','Do you plan to deploy Code Dx using Flux or Bitnami''s Sealed Secrets?',($yes,$no),0)
}

$prereqMessages = @()
if (-not (Test-SetupPreqs ([ref]$prereqMessages) -useSealedSecrets:($choice -eq 0) -checkKubectlVersion)) {
	Write-Host "`nYour system does not meet the Guided Setup prerequisites:`n"
	$prereqMessages | ForEach-Object {
		Write-Host "* $_`n"
	}
	exit 1
}
Write-Host "`n`nYour system meets the Guided Setup prerequisites.`n"
