<#PSScriptInfo
.VERSION 1.3.0
.GUID d65a6b13-910d-4220-8cfb-5de8cdd52011
.AUTHOR Black Duck
.COPYRIGHT Copyright 2024 Black Duck Software, Inc. All rights reserved.
#>

<# 
.DESCRIPTION 
This script includes functions for Velero-related tasks.
#>

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

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
	[switch] $skipToolOrchestration,
	[switch] $dryRun) {

	if (-not $dryRun) {
		if (Test-VeleroBackupSchedule $scheduleNamespace $scheduleName) {
			Remove-VeleroBackupSchedule $scheduleNamespace $scheduleName
		}
	}

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
spec:
  schedule: '{1}'
  template:
    includedNamespaces: {2}
    storageLocation: default
    ttl: {3}
    includeClusterResources: true
'@ -f $scheduleName, `
	$scheduleExpression, `
	$includedNamespaces, `
	$backupTimeToLive

	if (-not $skipDatabaseBackup) {

		$hookTemplate = @'

    hooks:
      resources:
      - name: database-backup
        includedNamespaces:
        - '{0}'
        labelSelector:
          matchLabels:
            app: mariadb
            component: slave
            release: {3}
        pre:
        - exec:
            container: mariadb
            command:
            - /bin/bash
            - -c
            - /bitnami/mariadb/scripts/backup.sh && sleep {1}
            timeout: '{2}'
'@ -f 	$codeDxNamespace, `
		$backupLagTime, `
		$backupTimeout, `
		$codeDxReleaseName

		$scheduleTemplate += $hookTemplate
	}

	$scheduleTemplate | out-file $scheduleFilePath -Encoding ascii -Force

	$output = $dryRun ? 'yaml' : 'name'
	$dryRunParam = $dryRun ? (Get-KubectlDryRunParam) : ''

	kubectl -n $scheduleNamespace create -f $scheduleFilePath -o $output $dryRunParam
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create the following Velero Schedule resource (kubectl exited with code $LASTEXITCODE):`n$scheduleTemplate"
	}
}
