<#PSScriptInfo
.VERSION 1.3.0
.GUID 1830f430-23af-46c2-b73c-8b936957b671
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script helps you migrate Code Dx data from a system created by the 
Code Dx Installer to a Code Dx deployment running on k8s (with or 
without an external database).
#>

param (
	[string] $appDataPath,
	[string] $dumpFile,
	[string] $rootPwd,
	[string] $replicationPwd,
	[string] $namespaceCodeDx = 'cdx-app',
	[string] $releaseNameCodeDx = 'codedx',
	[int]    $waitSeconds = 600,
	[switch] $externalDatabase
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

$global:PSNativeCommandArgumentPassing='Legacy'

'../.install-guided-setup-module.ps1','../setup/core/common/mariadb.ps1','../setup/core/common/codedx.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

$internalDatabase = -not $externalDatabase

if ($appDataPath -eq '') { 
	$appDataPath = Read-HostText 'Enter the path to your Code Dx AppData folder' 1 
}

if (-not (Test-Path $appDataPath -PathType Container)) {
	Write-Error "Unable to find Code Dx AppData folder at $appDataPath."
}

$analysisFiles = join-path $appDataPath 'analysis-files'
if (-not (Test-Path $analysisFiles -PathType Container)) {
	Write-Error "Unable to find Code Dx AppData analysis-files folder at $analysisFiles."
}

if ($internalDatabase) {

	if ($dumpFile -eq '') {
		$dumpFile = Read-HostText 'Enter the path to your mysqldump file' 1
	}

	if (-not (Test-Path $dumpFile -PathType Leaf)) {
		Write-Error "Unable to find mysqldumpfile at $dumpFile."
	}

	if ($rootPwd -eq '') {
		$rootPwd = Read-HostSecureText 'Enter the password for the MariaDB root user' 1
	}

	if ($replicationPwd -eq '') {
		$replicationPwd = Read-HostSecureText 'Enter the password for the MariaDB replicator user' 1
	}
}

if (-not (Test-Namespace $namespaceCodeDx)) {
	$namespaceCodeDx = Read-HostText 'Enter the Code Dx k8s namespace' 1
}

if (-not (Test-HelmRelease $namespaceCodeDx $releaseNameCodeDx)) {
	$releaseNameCodeDx = Read-HostText "Enter the Code Dx Helm release name in the $namespaceCodeDx namespace" 1
}

if (-not (Test-HelmRelease $namespaceCodeDx $releaseNameCodeDx)) {
	Write-Error "Unable to find Helm release named $releaseNameCodeDx in namespace $namespaceCodeDx."
}

$deploymentCodeDx = Get-CodeDxChartFullName $releaseNameCodeDx

$statefulSetMariaDBMaster = ''
$statefulSetMariaDBSlave  = ''
$mariaDbSecretName        = ''
$mariaDbMasterServiceName = ''

if ($internalDatabase) {

	$statefulSetMariaDBMaster = "$releaseNameCodeDx-mariadb-master"
	$statefulSetMariaDBSlave  = "$releaseNameCodeDx-mariadb-slave"
	$mariaDbSecretName        = "$releaseNameCodeDx-mariadb-pd"
	$mariaDbMasterServiceName = "$releaseNameCodeDx-mariadb"
}

if (-not (Test-Deployment $namespaceCodeDx $deploymentCodeDx)) {
	Write-Error "Unable to find Deployment named $deploymentCodeDx in namespace $namespaceCodeDx."
}

if ($internalDatabase) {

	if (-not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBMaster)) {
		Write-Error "Unable to find StatefulSet named $statefulSetMariaDBMaster in namespace $namespaceCodeDx."
	}

	if (-not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBSlave)) {
		Write-Error "Unable to find StatefulSet named $statefulSetMariaDBSlave in namespace $namespaceCodeDx."
	}

	if (-not (Test-Secret $namespaceCodeDx $mariaDbSecretName)) {
		Write-Error "Unable to find Secret named $mariaDbSecretName in namespace $namespaceCodeDx."
	}

	if (-not (Test-Service $namespaceCodeDx $mariaDbMasterServiceName)) {
		Write-Error "Unable to find Service named $mariaDbMasterServiceName in namespace $namespaceCodeDx."
	}
}

$statefulSetMariaDBSlaveCount = 0
if ($internalDatabase) {
	$statefulSetMariaDBSlaveCount = (Get-HelmValues $namespaceCodeDx $releaseNameCodeDx).mariadb.slave.replicas
}

Write-Host @"

Using the following configuration:

Code Dx Deployment Name:         $deploymentCodeDx
External Database:               $externalDatabase
MariaDB Master StatefulSet Name: $statefulSetMariaDBMaster
MariaDB Slave StatefulSet Name:  $statefulSetMariaDBSlave
MariaDB Slave Replica Count:     $statefulSetMariaDBSlaveCount
MariaDB Secret Name:             $mariaDbSecretName
MariaDB Master Service Name:     $mariaDbMasterServiceName
"@

if ($internalDatabase) {

	Write-Verbose 'Searching for MariaDB slave pods...'
	$podFullNamesSlaves = kubectl -n $namespaceCodeDx get pod -l component=slave -o name
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to fetch slave pods, kubectl exited with exit code $LASTEXITCODE."
	}

	$podNamesSlaves = @()
	$podFullNamesSlaves | ForEach-Object {

		$podName = $_ -replace 'pod/',''
		$podNamesSlaves = $podNamesSlaves + $podName
	}

	if ($statefulSetMariaDBSlaveCount -ne $podNamesSlaves.Count) {
		Write-Error "Make sure all subordinate databases are running and retry."
	}
}

Write-Verbose 'Searching for Code Dx pods...'
$podNameCodeDx = kubectl -n $namespaceCodeDx get pod -l component=frontend -o name
if (0 -ne $LASTEXITCODE) {
	Write-Error "Unable to find Code Dx pod, kubectl exited with exit code $LASTEXITCODE."
}
$podNameCodeDx = $podNameCodeDx -replace 'pod/',''

if ($internalDatabase) {

	Write-Verbose 'Searching for MariaDB master pod...'
	$podNameMaster = kubectl -n $namespaceCodeDx get pod -l component=master -o name
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to find MariaDB master pod, kubectl exited with exit code $LASTEXITCODE."
	}
	$podNameMaster = $podNameMaster -replace 'pod/',''

	if (-not (Test-Database $namespaceCodeDx $podNameMaster 'mariadb' $rootPwd)) {
		Write-Error "Unable to log on to the MariaDB server as root. Is the password correct?"
	}
}

Write-Verbose "Stopping Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 0 $waitSeconds

if ($internalDatabase) {

	Write-Verbose 'Stopping slave database instances...'
	$podNamesSlaves | ForEach-Object {
		Write-Verbose "Stopping slave named $podName..."
		Stop-SlaveDB $namespaceCodeDx $podName 'mariadb' $rootPwd
	}

	Write-Verbose "Restoring database on pod $podNameMaster..."
	New-Database $namespaceCodeDx $podNameMaster 'mariadb' $rootPwd 'codedx' $dumpFile

	$podNamesSlaves | ForEach-Object {
		Write-Verbose "Restoring database on pod $_..."
		New-Database $namespaceCodeDx $_ 'mariadb' $rootPwd 'codedx' $dumpFile
	}

	Write-Verbose 'Resetting master database...'
	$filePos = Get-MasterFilePosAfterReset $namespaceCodeDx 'mariadb' $podNameMaster $rootPwd

	Write-Verbose 'Connecting slave database(s)...'
	$podNamesSlaves | ForEach-Object {
		Write-Verbose "Restoring slave database pod $_..."
		Stop-SlaveDB  $namespaceCodeDx $_ 'mariadb' $rootPwd
		Start-SlaveDB $namespaceCodeDx $_ 'mariadb' 'replicator' $replicationPwd $rootPwd $mariaDbMasterServiceName $filePos
	}
} else {

	$externalDatabaseInstructions = @'

Since your Code Dx Kubernetes deployment uses an external Code Dx database (one
that you maintain on your own that is not installed or updated by the Code Dx
Kubernetes deployment script), you must restore the dump-codedx.sql file you 
created in Step 2 of the Migrate Code Dx Data to Kubernetes instructions.

You can restore mysqldump files using a command that looks like this:

  mysql -uroot --password=root-password codedxdb < dump-codedx.sql

'@
	Write-Host $externalDatabaseInstructions
	Read-Host -Prompt 'Restore your database (see above) and then press Enter to continue...'
}

Write-Verbose "Starting Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 1 $waitSeconds

Write-Verbose "Fetching Code Dx pod name for deployment named $deploymentCodeDx..."
$codeDxPodName = kubectl -n $namespaceCodeDx get pod -l app=codedx -o name
if (0 -ne $LASTEXITCODE) {
	Write-Error "Unable to find Code Dx pod in namespace  $namespaceCodeDx."
}
$codeDxPodName = $codeDxPodName -replace 'pod/',''

Write-Verbose "Copying analysis-files to Code Dx volume..."
Copy-K8sItem $namespaceCodeDx $analysisFiles $codeDxPodName 'codedx' '/opt/codedx'

$keystoreFiles = join-path $appDataPath 'keystore'
if (Test-Path $keystoreFiles -PathType Container) {
	Write-Verbose 'Copying keystore to Code Dx volume...'
	Write-Verbose 'NOTE: SAML configuration under keystore must be compatible with current k8s deployment.'
	Copy-K8sItem $namespaceCodeDx $keystoreFiles $codeDxPodName 'codedx' '/opt/codedx'
}

$mlTriageFiles = join-path $appDataPath 'mltriage-files'
if (Test-Path $mlTriageFiles -PathType Container) {
	Write-Verbose "Copying mltriage-files to Code Dx volume..."
	Copy-K8sItem $namespaceCodeDx $mlTriageFiles $codeDxPodName 'codedx' '/opt/codedx'
}

Write-Verbose "Restarting Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 0 $waitSeconds
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 1 $waitSeconds

Write-Verbose "`nNote: The database restore may have changed your Code Dx admin password.`n"
Write-Host 'Done'
