<#PSScriptInfo
.VERSION 1.0.1
.GUID 7324446b-ac6b-4870-846d-bef7547de642
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script uses Helm to install and configure Code Dx and Code Dx Orchestration 
on an AWS EKS cluster.

The following tools must be installed and included in your PATH

1 helm tool (v3)
2 kubectl
3 openssl
4 git
5 keytool
#>

param (
  [string] $storageClassName = 'gp2'
)
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'../core/common/network.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

$provisionNetworkPolicy = {
	Write-Verbose 'Adding AWS Calico Network Policy Provider...'
	Add-AwsCalicoNetworkPolicyProvider @args
}

& (join-path $PSScriptRoot '../core/setup.ps1') `
  -storageClassName $storageClassName `
  -provisionNetworkPolicy $provisionNetworkPolicy @args
