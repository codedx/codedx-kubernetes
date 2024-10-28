<#PSScriptInfo
.VERSION 1.1.0
.GUID 4962d6c1-c37b-491e-b926-181c915b3d8d
.AUTHOR Black Duck
.COPYRIGHT Copyright 2024 Black Duck Software, Inc. All rights reserved.
.DESCRIPTION Starts the Code Dx Guided Setup after conditionally helping with module installation.
#>

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

$global:PSNativeCommandArgumentPassing='Legacy'

. $PSScriptRoot/.install-guided-setup-module.ps1
. $PSScriptRoot/.guided-setup.ps1
