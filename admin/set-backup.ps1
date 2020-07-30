<#PSScriptInfo
.VERSION 1.0.1
.GUID 7686d012-1a04-43f0-a56c-8710ab6e11ff
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script automates the process of applying Velero configuration to Code Dx.
#>


param (
	[string] $namespaceCodeDx = 'cdx-app',
	[string] $releaseNameCodeDx = 'codedx',

	[string] $namespaceCodeDxToolOrchestration = 'cdx-svc',
	[string] $releaseNameCodeDxToolOrchestration = 'codedx-tool-orchestration',

	[string] $scheduleCronExpression = '0 3 * * *',
	[string] $databaseBackupTimeout = '30m',
	[string] $databaseBackupTimeToLive = '720h0m0s',

	[switch] $useVeleroResticIntegration,

	[switch] $skipDatabaseBackup,
	[switch] $skipToolOrchestration,

	[string] $workDirectory = '~',
	[string] $namespaceVelero = 'velero',

	[switch] $delete
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

'../setup/core/common/k8s.ps1','../setup/core/common/helm.ps1','../setup/core/common/codedx.ps1','../setup/core/common/velero.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

Write-Verbose "Testing for work directory '$workDirectory'"
if (-not (Test-Path $workDirectory -PathType Container)) {
	Write-Error "Unable to find specified directory ($workDirectory). Does it exist?"
}

if (-not (Test-HelmRelease $namespaceCodeDx $releaseNameCodeDx)) {
	Write-Error "Unable to find Helm release named $releaseNameCodeDx in namespace $namespaceCodeDx."
}

if (-not $skipToolOrchestration) {
	if (-not (Test-HelmRelease $namespaceCodeDxToolOrchestration $releaseNameCodeDxToolOrchestration)) {
		Write-Error "Unable to find Helm release named $releaseNameCodeDxToolOrchestration in namespace $namespaceCodeDxToolOrchestration."
	}
}

$deploymentCodeDx = Get-CodeDxChartFullName $releaseNameCodeDx
$statefulSetMariaDBSlave = "$releaseNameCodeDx-mariadb-slave"
$deploymentCodeDxToolOrchestration = Get-CodeDxToolOrchestrationChartFullName $releaseNameCodeDxToolOrchestration
$deploymentMinio = "$releaseNameCodeDxToolOrchestration-minio"

if (-not (Test-Deployment $namespaceCodeDx $deploymentCodeDx)) {
	Write-Error "Unable to find Deployment named $deploymentCodeDx in namespace $namespaceCodeDx."
}

$applyBackupConfiguration = -not $delete

if (-not $skipDatabaseBackup -and $applyBackupConfiguration) {
	$statefulSetMariaDBSlaveCount = (Get-HelmValues $namespaceCodeDx $releaseNameCodeDx).mariadb.slave.replicas
	if ($statefulSetMariaDBSlaveCount -eq 0) {
		Write-Error "Unable to apply backup configuration because database backups require at least one MariaDB slave replica."
	}
}

if (-not $skipDatabaseBackup -and -not (Test-StatefulSet $namespaceCodeDx $statefulSetMariaDBSlave)) {
	Write-Error "Unable to find StatefulSet named $statefulSetMariaDBSlave in namespace $namespaceCodeDx."
}

if (-not $skipToolOrchestration) {

	if (-not (Test-Deployment $namespaceCodeDxToolOrchestration $deploymentCodeDxToolOrchestration)) {
		Write-Error "Unable to find Deployment named $deploymentCodeDxToolOrchestration in namespace $namespaceCodeDxToolOrchestration."
	}

	if (-not (Test-Deployment $namespaceCodeDxToolOrchestration $deploymentMinio)) {
		Write-Error "Unable to find Deployment named $deploymentMinio in namespace $namespaceCodeDxToolOrchestration."
	}

} else {
	$deploymentCodeDxToolOrchestration = ''
	$deploymentMinio = ''
}

$subordinateDatabaseLabel = $statefulSetMariaDBSlave
if ($skipDatabaseBackup) {
	$subordinateDatabaseLabel = 'n/a'
}

Write-Host @"

Using the following configuration:

Code Dx Deployment Name: $deploymentCodeDx
MariaDB Slave StatefulSet Name: $subordinateDatabaseLabel
Code Dx Tool Orchestration Deployment Name: $deploymentCodeDxToolOrchestration
MinIO Deployment Name: $deploymentMinio
Use Restic: $useVeleroResticIntegration
Install: $applyBackupConfiguration
Skip Tool Orchestration: $skipToolOrchestration
Skip Database: $skipDatabaseBackup

"@

if ($useVeleroResticIntegration) {

	# When using Restic integration for volume backup, specify the volumes to 
	# back up (Code Dx codedx-appdata, MariaDB backup, and MinIO data)

	if ($applyBackupConfiguration) {

		# Add annotations to include volumes in backup
		$installPatch = "spec:`n  template:`n    metadata:`n      annotations:`n        backup.velero.io/backup-volumes: '{0}'"
		Edit-ResourceStrategicPatch $namespaceCodeDx 'deployment' $deploymentCodeDx ($installPatch -f 'codedx-appdata')
		if (-not $skipDatabaseBackup) {
			Edit-ResourceStrategicPatch $namespaceCodeDx 'statefulset' $statefulSetMariaDBSlave ($installPatch -f 'backup')
		}
		if (-not $skipToolOrchestration) {
			Edit-ResourceStrategicPatch $namespaceCodeDxToolOrchestration 'deployment' $deploymentMinio ($installPatch -f 'data')
		}

	} else {

		# Remove annotations that include volumes in backup
		$uninstallPatch = ConvertTo-Json @(@{'op'='remove';'path'='/spec/template/metadata/annotations/backup.velero.io~1backup-volumes'})
		Edit-ResourceJsonPath $namespaceCodeDx 'deployment' $deploymentCodeDx $uninstallPatch
		if (-not $skipDatabaseBackup) {
			Edit-ResourceJsonPath $namespaceCodeDx 'statefulset' $statefulSetMariaDBSlave $uninstallPatch
		}
		if (-not $skipToolOrchestration) {
			Edit-ResourceJsonPath $namespaceCodeDxToolOrchestration 'deployment' $deploymentMinio $uninstallPatch
		}
	}

} else {

	# When using volume snapshot providers, skip the unnecessary back up of 
	# MariaDB data volumes that get restored by the database backup

	$pvcs = kubectl -n $namespaceCodeDx get pvc -l app=mariadb -o name
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Unable to edit resource with strategic patch, kubectl exited with code $LASTEXITCODE."
	}

	$exclusionLabelKey = 'velero.io/exclude-from-backup'
	$exclusionLabelValue = 'true'

	$pvs = @()
	$pvcs | Where-Object { $_ -like 'persistentvolumeclaim/data*' } | ForEach-Object {

		$pvs += 'pv/{0}' -f (kubectl -n $namespaceCodeDx get $_ -o jsonpath='{.spec.volumeName}')
		if ($LASTEXITCODE -ne 0) {
			Write-Error "Unable to fetch PV name from $_, kubectl exited with code $LASTEXITCODE."
		}

		if ($applyBackupConfiguration) {
			# Added labels to exclude MariaDB data PVCs from backup must be reapplied post-restore
			Add-ResourceLabel $namespaceCodeDx $_ $exclusionLabelKey $exclusionLabelValue
		} else {
			Remove-ResourceLabel $namespaceCodeDx $_ $exclusionLabelKey
		}
	}

	$pvs | ForEach-Object {
		if ($applyBackupConfiguration) {
			# Added labels to exclude MariaDB data PVCs from backup must be reapplied post-restore
			Add-ResourceLabel '' $_ $exclusionLabelKey $exclusionLabelValue
		} else {
			Remove-ResourceLabel '' $_ $exclusionLabelKey
		}
	}
}

$scheduleName = "$releaseNameCodeDx-schedule"

if ($delete) {

	Write-Verbose "Deleting Velero Schedule resource $scheduleName..."
	if (Test-VeleroBackupSchedule $namespaceVelero $scheduleName) {
		Remove-VeleroBackupSchedule $namespaceVelero $scheduleName
	}

} else {

	Write-Verbose "Creating Velero Schedule resource $scheduleName..."
	New-VeleroBackupSchedule $workDirectory $scheduleName `
		'schedule.yaml' `
		$releaseNameCodeDx `
		$namespaceVelero `
		$scheduleCronExpression `
		$namespaceCodeDx `
		$namespaceCodeDxToolOrchestration `
		$databaseBackupTimeout `
		$databaseBackupTimeToLive `
		-skipDatabaseBackup:$skipDatabaseBackup `
		-skipToolOrchestration:$skipToolOrchestration
}

Write-Host 'Done'
