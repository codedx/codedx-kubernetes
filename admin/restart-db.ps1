<#PSScriptInfo
.VERSION 1.0.1
.GUID a48bc8e0-dada-4b63-944a-9397ce91f0b3
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script automates the process of restarting the MariaDB databases.
#>


param (
	[string] $namespaceCodeDx = 'cdx-app',
	[string] $releaseNameCodeDx = 'codedx',
	[int]    $waitSeconds = 600
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'../setup/core/common/k8s.ps1','../setup/core/common/helm.ps1','../setup/core/common/codedx.ps1' | ForEach-Object {
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

if (-not (Test-Deployment $namespaceCodeDx $deploymentCodeDx)) {
	Write-Error "Unable to find Deployment named $deploymentCodeDx in namespace $namespaceCodeDx."
}

if (-not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBMaster)) {
	Write-Error "Unable to find StatefulSet named $statefulSetMariaDBMaster in namespace $namespaceCodeDx."
}

if (-not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBSlave)) {
	Write-Error "Unable to find StatefulSet named $statefulSetMariaDBSlave in namespace $namespaceCodeDx."
}

$statefulSetMariaDBSlaveCount = (Get-HelmValues $namespaceCodeDx $releaseNameCodeDx).mariadb.slave.replicas

Write-Host @"

Using the following configuration:

Code Dx Deployment Name: $deploymentCodeDx
MariaDB Master StatefulSet Name: $statefulSetMariaDBMaster
MariaDB Slave StatefulSet Name: $statefulSetMariaDBSlave
MariaDB Slave Replica Count: $statefulSetMariaDBSlaveCount

"@

Write-Verbose "Stopping Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 0 $waitSeconds

Write-Verbose "Stopping $statefulSetMariaDBMaster statefulset replica..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBMaster 0 $waitSeconds

Write-Verbose "Stopping $statefulSetMariaDBSlave statefulset replica(s)..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBSlave 0 $waitSeconds

Write-Verbose "Starting $statefulSetMariaDBMaster statefulset replica..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBMaster 1 $waitSeconds

Write-Verbose "Starting $statefulSetMariaDBSlave statefulset replica(s)..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBSlave $statefulSetMariaDBSlaveCount $waitSeconds

Write-Verbose "Starting Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 1 $waitSeconds

Write-Host 'Done'
