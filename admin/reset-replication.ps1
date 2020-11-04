<#PSScriptInfo
.VERSION 1.0.0
.GUID 047d9f7c-d726-4873-9e47-c6bfeebd76ad
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script automates the process of reseting the MariaDB database replication.
#>


param (
	[string] $rootPwd = '',
	[string] $namespaceCodeDx = 'cdx-app',
	[string] $releaseNameCodeDx = 'codedx',
	[int]    $waitSeconds = 600,
	[switch] $skipCodeDxRestart
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'../setup/core/common/mariadb.ps1','../setup/core/common/k8s.ps1','../setup/core/common/helm.ps1','../setup/core/common/codedx.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

if (-not (Test-HelmRelease $namespaceCodeDx $releaseNameCodeDx)) {
	Write-Error "Unable to find Helm release named $releaseNameCodeDx in namespace $namespaceCodeDx."
}

$deploymentCodeDx = Get-CodeDxChartFullName $releaseNameCodeDx
$statefulSetMariaDBMaster = "$releaseNameCodeDx-mariadb-master"
$statefulSetMariaDBSlave = "$releaseNameCodeDx-mariadb-slave"
$mariaDbMasterServiceName = "$releaseNameCodeDx-mariadb"

if (-not (Test-Deployment $namespaceCodeDx $deploymentCodeDx)) {
	Write-Error "Unable to find Deployment named $deploymentCodeDx in namespace $namespaceCodeDx."
}

if (-not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBMaster)) {
	Write-Error "Unable to find StatefulSet named $statefulSetMariaDBMaster in namespace $namespaceCodeDx."
}

if (-not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBSlave)) {
	Write-Error "Unable to find StatefulSet named $statefulSetMariaDBSlave in namespace $namespaceCodeDx."
}

if (-not (Test-Service $namespaceCodeDx $mariaDbMasterServiceName)) {
	Write-Error "Unable to find Service named $mariaDbMasterServiceName in namespace $namespaceCodeDx."
}

$statefulSetMariaDBSlaveCount = (Get-HelmValues $namespaceCodeDx $releaseNameCodeDx).mariadb.slave.replicas
if ($statefulSetMariaDBSlaveCount -eq 0) {
	Write-Error "Unable to find any subordinate database instances for release $releaseNameCodeDx in namespace $namespaceCodeDx."
}

Write-Host @"

Using the following configuration:

Code Dx Deployment Name: $deploymentCodeDx
MariaDB Master StatefulSet Name: $statefulSetMariaDBMaster
MariaDB Slave StatefulSet Name: $statefulSetMariaDBSlave
MariaDB Slave Replica Count: $statefulSetMariaDBSlaveCount
MariaDB Master Service Name: $mariaDbMasterServiceName
"@

if ($rootPwd -eq '') { 
	$rootPwd = Read-HostSecureText 'Enter the password for the MariaDB root user' 1 
}

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

Write-Verbose 'Searching for Code Dx pods...'
$podNameCodeDx = kubectl -n $namespaceCodeDx get pod -l component=frontend -o name
if (0 -ne $LASTEXITCODE) {
	Write-Error "Unable to find Code Dx pod, kubectl exited with exit code $LASTEXITCODE."
}
$podNameCodeDx = $podNameCodeDx -replace 'pod/',''

Write-Verbose 'Searching for MariaDB master pod...'
$podNameMaster = kubectl -n $namespaceCodeDx get pod -l component=master -o name
if (0 -ne $LASTEXITCODE) {
	Write-Error "Unable to find MariaDB master pod, kubectl exited with exit code $LASTEXITCODE."
}
$podNameMaster = $podNameMaster -replace 'pod/',''

Write-Verbose "Stopping Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 0 $waitSeconds

Write-Verbose 'Stopping slave database instances...'
$podNamesSlaves | ForEach-Object {
	Write-Verbose "Stopping slave named $podName..."
	Stop-SlaveDB $namespaceCodeDx $podName 'mariadb' $rootPwd
}

Write-Verbose 'Resetting master database...'
$filePos = Get-MasterFilePosAfterReset $namespaceCodeDx 'mariadb' $podNameMaster $rootPwd

Write-Verbose 'Connecting slave database(s)...'
$podNamesSlaves | ForEach-Object {
	Write-Verbose "Restoring slave database pod $_..."
	Start-SlaveDB $namespaceCodeDx $_ 'mariadb' $rootPwd $mariaDbMasterServiceName $filePos
}

if ($skipCodeDxRestart) {
	Write-Verbose "Skipping Code Dx Restart..."
	Write-Verbose " To restart Code Dx, run: kubectl -n $namespaceCodeDx scale --replicas=1 deployment/$deploymentCodeDx"
} else {
	Write-Verbose "Starting Code Dx deployment named $deploymentCodeDx..."
	Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 1 $waitSeconds
}

Write-Host 'Done'
