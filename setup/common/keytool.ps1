
function Test-KeystorePassword([string] $keystorePath, [string] $keystorePwd) {

	keytool -list -keystore $keystorePath -storepass $keystorePwd | out-null
	$LASTEXITCODE -eq 0
}

function Set-KeystorePassword([string] $keystorePath, [string] $keystorePwd, [string] $newKeystorePwd) {

	if (-not (Test-KeystorePassword $keystorePath $keystorePwd)) {
		if (Test-KeystorePassword $keystorePath $newKeystorePwd) {
			return # password is already set
		}
		throw "Unable to change keystore password because the specified old keystore password is invalid for file '$keystorePath'"
	}

	keytool -storepasswd -keystore $keystorePath -storepass $keystorePwd -new $newKeystorePwd
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change keystore password, keytool exited with code $LASTEXITCODE."
	}
}

function Remove-KeystoreAlias([string] $keystorePath, [string] $keystorePwd, [string] $aliasName) {

	keytool -delete -alias $aliasName -keystore $keystorePath -storepass $keystorePwd
}

function Add-KeystoreAlias([string] $keystorePath, [string] $keystorePwd, [string] $aliasName, [string] $certFile) {

	keytool -import -trustcacerts -keystore $keystorePath -file $certFile -alias $aliasName -noprompt -storepass $keystorePwd
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
		Import-TrustedCaCert $caCertsFilePath $keystorePwd $_
	}
}
