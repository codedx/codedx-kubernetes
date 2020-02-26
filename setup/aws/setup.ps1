$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. (join-path $PSScriptRoot 'network.ps1')

$provisionNetworkPolicy = { 
	Write-Verbose 'Adding AWS Calico Network Policy Provider...'
	Add-AwsCalicoNetworkPolicyProvider @args 
}

& (join-path $PSScriptRoot '../setup.ps1') -provisionNetworkPolicy $provisionNetworkPolicy @args
