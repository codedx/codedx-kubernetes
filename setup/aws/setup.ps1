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

. (join-path $PSScriptRoot 'network.ps1')

$provisionNetworkPolicy = {
	Write-Verbose 'Adding AWS Calico Network Policy Provider...'
	Add-AwsCalicoNetworkPolicyProvider @args
}

& (join-path $PSScriptRoot '../setup.ps1') `
  -storageClassName $storageClassName `
  -provisionNetworkPolicy $provisionNetworkPolicy @args
