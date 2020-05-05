<#PSScriptInfo
.VERSION 1.0.1
.GUID 01d0c54b-ce7a-4462-b4cd-fb27a4f847bc
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script uses Helm to install and configure Code Dx and Code Dx Orchestration 
on an Azure AKS cluster.

The following tools must be installed and included in your PATH

1 helm tool (v3)
2 kubectl
3 openssl
4 git
5 keytool
#>

param (
  [string] $storageClassName = 'managed-premium',
  [string] $nginxIngressControllerLoadBalancerIP
)
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

# Note: Avoid '[Parameter(Mandatory=$true)]' due to @args affect
if ($nginxIngressControllerLoadBalancerIP -eq '') {
  $nginxIngressControllerLoadBalancerIP = read-host -prompt 'Enter ingress load balancer IP:'
}

& (join-path $PSScriptRoot '../setup.ps1') `
  -storageClassName $storageClassName `
  -nginxIngressControllerLoadBalancerIP $nginxIngressControllerLoadBalancerIP `
  @args

Write-Verbose 'Deployment complete!'
