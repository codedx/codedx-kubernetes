<#PSScriptInfo
.VERSION 1.0.3
.GUID 6b1307f7-7098-4c65-9a86-8478840ad4cd
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for the deployment of Code Dx and Code Dx Orchestration.
#>

'utils.ps1',
'k8s.ps1',
'helm.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Get-CodeDxPdSecretName([string] $releaseName) {
	"$releaseName-codedx-pd"
}

function New-CodeDxPdSecret([string] $namespace, [string] $releaseName, 
	[string] $adminPwd, [string] $caCertsFilePwd,
	[string] $externalDbUser, [string] $externalDbPwd) {

	$data = @{"admin-password"=$adminPwd;"cacerts-password"=$caCertsFilePwd}
	
	if ('' -ne $externalDbUser) {
		$data['mariadb-codedx-username'] = $externalDbUser
	}
	if ('' -ne $externalDbPwd) {
		$data['mariadb-codedx-password'] = $externalDbPwd
	}

	New-GenericSecret $namespace (Get-CodeDxPdSecretName $releaseName) $data
}

function Get-AdminPwdFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-CodeDxPdSecretName $releaseName) 'admin-password'
}

function Get-CacertsPasswordFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-CodeDxPdSecretName $releaseName) 'cacerts-password'
}

function Get-ExternalDatabaseUserFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-CodeDxPdSecretName $releaseName) 'mariadb-codedx-username'
}

function Get-ExternalDatabasePasswordFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-CodeDxPdSecretName $releaseName) 'mariadb-codedx-password'
}

function Get-DatabasePdSecretName([string] $releaseName) {
	"$releaseName-mariadb-pd"
}

function New-DatabasePdSecret([string] $namespace, [string] $releaseName, 
	[string] $mariadbRootPwd, [string] $mariadbReplicatorPwd) {

	# excluding "mariadb-password" from MariaDb credential secret because db.user is unspecfied
	New-GenericSecret $namespace (Get-DatabasePdSecretName $releaseName) @{"mariadb-root-password"=$mariadbRootPwd;"mariadb-replication-password"=$mariadbReplicatorPwd}
}

function Get-DatabaseRootPasswordFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-DatabasePdSecretName $releaseName) 'mariadb-root-password'
}

function Get-DatabaseReplicationPasswordFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-DatabasePdSecretName $releaseName) 'mariadb-replication-password'
}

function Get-ToolServicePdSecretName([string] $releaseName) {
	"$releaseName-tool-service-pd"
}

function New-ToolServicePdSecret([string] $namespace, [string] $releaseName, [string] $apiKey) {
	New-GenericSecret $namespace (Get-ToolServicePdSecretName $releaseName) @{"api-key"=$apiKey}
}

function Get-ToolServiceApiKeyFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-ToolServicePdSecretName $releaseName) 'api-key'
}

function Get-MinioPdSecretName([string] $releaseName) {
	"$releaseName-minio-pd"
}

function New-MinioPdSecret([string] $namespace, [string] $releaseName, [string] $minioUsername, [string] $minioPwd) {
	New-GenericSecret $namespace (Get-MinioPdSecretName $releaseName) @{"access-key"=$minioUsername;"secret-key"=$minioPwd}
}

function Get-MinioUsernameFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-MinioPdSecretName $releaseName) 'access-key'
}

function Get-MinioPasswordFromPd([string] $namespace, [string] $releaseName) {
	Get-SecretFieldValue $namespace (Get-MinioPdSecretName $releaseName) 'secret-key'
}
