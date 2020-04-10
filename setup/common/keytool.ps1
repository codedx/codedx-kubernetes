
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
