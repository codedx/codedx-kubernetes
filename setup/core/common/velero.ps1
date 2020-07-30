<#PSScriptInfo
.VERSION 1.0.0
.GUID d65a6b13-910d-4220-8cfb-5de8cdd52011
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for Velero-related tasks.
#>

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict


function Test-VeleroBackupSchedule([string] $namespace, [string] $name) {

	kubectl -n $namespace get "schedule/$name" | Out-Null
	$LASTEXITCODE -eq 0
}

function New-VeleroBackupSchedule([string] $workDir, 
	[string] $scheduleName,
	[string] $scheduleFilename,
	[string] $codeDxReleaseName,
	[string] $scheduleNamespace,
	[string] $scheduleExpression,
	[string] $codeDxNamespace,
	[string] $codeDxToolOrchestrationNamespace,
	[string] $backupTimeout,
	[string] $backupTimeToLive,
	[switch] $skipDatabaseBackup,
	[switch] $skipToolOrchestration) {

	$scheduleFilePath = join-path $workDir $scheduleFilename
	if (test-path $scheduleFilePath) {
		remove-item $scheduleFilePath -force
	}

	# Backup lag time found to be necessary to mitigate the chance of a volume snapshot 
	# missing the backup files (produced by the pre-backup hook) because it occurred too 
	# soon after the backup script finished.
	$backupLagTime = '1m'

	$namespaces = @($codeDxNamespace)
	if (-not $skipToolOrchestration) {
		$namespaces += $codeDxToolOrchestrationNamespace
	}
	$includedNamespaces = ConvertTo-YamlStringArray $namespaces

	$scheduleTemplate = @'
apiVersion: velero.io/v1
kind: Schedule
metadata:
  name: {0}
  namespace: {1}
spec:
  schedule: '{2}'
  template:
    includedNamespaces: {4}
    storageLocation: default
    ttl: {7}
    includeClusterResources: true
    hooks:
      resources:
      - name: database-backup
        includedNamespaces:
        - '{3}'
        labelSelector:
          matchLabels:
            app: mariadb
            component: slave
            release: codedx
        pre:
        - exec:
            container: mariadb
            command:
            - /bin/bash
            - -c
            - /bitnami/mariadb/scripts/backup.sh && sleep {5}
            timeout: '{6}'
'@ -f $scheduleName, `
	$scheduleNamespace,$scheduleExpression, `
	$codeDxNamespace, `
	$includedNamespaces, `
	$backupLagTime, $backupTimeout, $backupTimeToLive
	
	$scheduleTemplate | out-file $scheduleFilePath -Encoding ascii -Force

	kubectl apply -f $scheduleFilePath
	if ($LASTEXITCODE -ne 0) {
		Write-Error "Unable to create the following Velero Schedule resource (kubectl exited with code $LASTEXITCODE):`n$scheduleTemplate"
	}
}

function Remove-VeleroBackupSchedule([string] $namespace, [string] $name) {

	kubectl -n $namespace delete schedule $name | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete Velero Schedule named $name, kubectl exited with code $LASTEXITCODE."
	}
}
