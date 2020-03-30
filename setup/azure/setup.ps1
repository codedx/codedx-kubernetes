param (
  [string] $storageClassName = 'managed-premium',
  [string] $ingressLoadBalancerIP
)
$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

# Note: Avoid '[Parameter(Mandatory=$true)]' due to @args affect
if ($ingressLoadBalancerIP -eq '') {
  $ingressLoadBalancerIP = read-host -prompt 'Enter ingress load balancer IP:'
}

& (join-path $PSScriptRoot '../setup.ps1') `
  -storageClassName $storageClassName `
  -ingressLoadBalancerIP $ingressLoadBalancerIP `
  @args

Write-Verbose 'Deployment complete!'
