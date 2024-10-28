<#PSScriptInfo
.VERSION 1.3.0
.GUID 5c50ce4e-b948-4b48-bcf1-c003954a988b
.AUTHOR Black Duck
.COPYRIGHT Copyright 2024 Black Duck Software, Inc. All rights reserved.
#>

<# 
.DESCRIPTION 
This script runs a test using a CSR and the kubernetes.io/legacy-unknown signer.
#>

param (
  [string] $namespace = 'default',
  [string] $podName = 'code-dx-test-pod-csr',
  [string] $certFilename = 'ca.crt'
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

$global:PSNativeCommandArgumentPassing='Legacy'

$VerbosePreference = 'Continue'

'../../.install-guided-setup-module.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

Write-Host 'Testing for openssl...'
$opensslPath = Get-AppCommandPath 'openssl' | Select-Object -First 1
if ($null -eq $opensslPath) {
		Write-Error "Unable to continue because openssl is not in your PATH."
}

Write-Host 'Checking for kubernetes.io/legacy-unknown signer support...'
if (-not (Test-CertificateSigningRequestV1Beta1)) {
  Write-Error 'This cluster does not support the kubernetes.io/legacy-unknown signer.'
}

Write-Host "Testing for pod $podName in namespace $namespace."
if (Test-Pod $namespace $podName) {
  Write-Host "Removing pod $podName in namespace $namespace."
  Remove-Pod $namespace $podName
}

Write-Host "Running pod $podName in namespace $namespace."
$overrides = "--overrides=$('{"apiVersion":"v1","spec":{"automountServiceAccountToken":true}}' | convertto-json)"
kubectl -n $namespace run $podName --image=busybox --restart=Never $overrides -- sleep '300s'
if ($LASTEXITCODE -ne 0) {
  throw "Unable to start pod $podName to fetch certificate, kubectl exited with code $LASTEXITCODE."
}
Wait-RunningPod "Waiting for pod $podName in namespace $namespace." 300 $namespace $podName

$path = "/var/run/secrets/kubernetes.io/serviceaccount/$certFilename"
$tempPath = "/tmp/$certFilename"

Write-Host "Copying $path to $tempPath..."
kubectl -n $namespace exec $podName -- cp $path $tempPath
if ($LASTEXITCODE -ne 0) {
  throw "Unable to copy $path to $tempPath, kubectl exited with code $LASTEXITCODE."
}

Write-Host "Copying $tempPath from $podName..."
kubectl -n $namespace cp $podName`:$tempPath ./$certFilename
if ($LASTEXITCODE -ne 0) {
  throw "Unable to copy $certFilename file from $podName, kubectl exited with code $LASTEXITCODE."
}

Write-Host "Deleting pod $podName..."
Remove-Pod $namespace $podName -force

$resourceName = 'codedx-csr'
Write-Host "Creating new certificate using ./$certFilename..."
New-Certificate 'kubernetes.io/legacy-unknown' "./$certFilename" $resourceName 'codedx.default' 'codedx.public.key' 'codedx.private.key' $namespace 'codedx-alt.default'

Write-Host "Remove CSR $resourceName..."
Remove-CsrResource $resourceName

$subject  = (openssl x509 -noout -subject -in ./$certFilename).replace('subject=','')
$issuer = (openssl x509 -noout -issuer  -in ./codedx.public.key).replace('issuer=','')

if ($subject -ne $issuer) {
  throw "Certificate issuer ($issuer) is unexpected because it does not match subject ($subject)."
}

Write-Host "Done (used cert ./$certFilename)"
