<#PSScriptInfo
.VERSION 1.0.3
.GUID a0b1e49c-0f56-43fa-bd1d-ae211ac63c2a
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for keytool-related tasks.
#>

function Get-KeystorePasswordEscaped([string] $pwd) {
	$pwd.Replace('"','\"')
}

function Test-KeystorePassword([string] $keystorePath, [string] $keystorePwd) {

	$Local:ErrorActionPreference = 'SilentlyContinue'
	$keystorePwd = Get-KeystorePasswordEscaped $keystorePwd
	keytool -list -keystore $keystorePath -storepass $keystorePwd *>&1 | out-null
	$LASTEXITCODE -eq 0
}

function Set-KeystorePassword([string] $keystorePath, [string] $keystorePwd, [string] $newKeystorePwd) {

	if (-not (Test-KeystorePassword $keystorePath $keystorePwd)) {
		if (Test-KeystorePassword $keystorePath $newKeystorePwd) {
			return # password is already set
		}
		throw "Unable to change keystore password because the specified old keystore password is invalid for file '$keystorePath'"
	}

	keytool -storepasswd -keystore $keystorePath -storepass (Get-KeystorePasswordEscaped $keystorePwd) -new (Get-KeystorePasswordEscaped $newKeystorePwd)
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change keystore password, keytool exited with code $LASTEXITCODE."
	}
}

function Remove-KeystoreAlias([string] $keystorePath, [string] $keystorePwd, [string] $aliasName) {

	keytool -delete -alias $aliasName -keystore $keystorePath -storepass (Get-KeystorePasswordEscaped $keystorePwd)
}

function Add-KeystoreAlias([string] $keystorePath, [string] $keystorePwd, [string] $aliasName, [string] $certFile) {

	keytool -import -trustcacerts -keystore $keystorePath -file $certFile -alias $aliasName -noprompt -storepass (Get-KeystorePasswordEscaped $keystorePwd)
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to import certificate '$certFile' into keystore, keytool exited with code $LASTEXITCODE."
	}
}

function Get-TrustedCaCertAlias([string] $certFile) {
	split-path $certFile -leaf
}

function Import-TrustedCaCert([string] $keystorePath, [string] $keystorePwd, [string] $certFile) {

	if (-not (Test-Path $certFile -PathType Leaf)) {
		throw "Unable to import cert file '$certFile' because it does not exist."
	}

	$aliasName = Get-TrustedCaCertAlias $certFile

	Remove-KeystoreAlias $keystorePath $keystorePwd $aliasName
	Add-KeystoreAlias $keystorePath $keystorePwd $aliasName $certFile
}

function Import-TrustedCaCerts([string] $keystorePath, [string] $keystorePwd, [string[]] $certFiles) {

	if ($certFiles.Count -eq 0) {
		return
	}

	$uniqueAliasCount = ($certFiles | ForEach-Object {
		Get-TrustedCaCertAlias $_
	} | Select-Object -Unique).count

	if ($certFiles.Count -ne $uniqueAliasCount) {
		throw "Unable to import cert files because one or more certificates will map to the same alias"
	}

	$certFiles | ForEach-Object {
		Import-TrustedCaCert $keystorePath $keystorePwd $_
	}
}

function Test-Certificate([string] $path) {

	keytool -printcert -file $path | out-null
	$LASTEXITCODE -eq 0
}