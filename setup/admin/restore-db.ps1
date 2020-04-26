param (
	[string] $namespaceCodeDx = 'cdx-app',
	[string] $backupToRestore = '20200424-Full',
	[string] $workDirectory = '~',
	[string] $deploymentCodeDx = 'codedx',
	[string] $statefulSetMariaDBMaster = 'codedx-mariadb-master',
	[string] $statefulSetMariaDBSlave = 'codedx-mariadb-slave',
	[int]    $statefulSetMariaDBSlaveCount = 1,
	[string] $mariaDbSecretName = 'codedx-mariadb',
	[string] $mariaDbMasterServiceName = 'codedx-mariadb',
	[string] $rootPwd = '',
	[int]    $waitSeconds = 600
)

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

. (join-path $PSScriptRoot '../common/mariadb.ps1')
. (join-path $PSScriptRoot '../common/k8s.ps1')

if ($rootPwd -eq '') { 
	$rootPwd = Read-HostSecureText 'Enter a password for the MariaDB root user' 1 
}

Write-Verbose "Testing for work directory '$workDirectory'"
if (-not (Test-Path $workDirectory -PathType Container)) {
	Write-Error "Unable to find specified directory ($workDirectory). Does it exist?"
}

$workDirectory = join-path $workDirectory 'backup-files'
Write-Verbose "Testing for directory at '$workDirectory'"
if (Test-Path $workDirectory -PathType Container) {
	Write-Error "Unable to continue because $workDirectory already exists. Remove the directory and rerun this script."
}

$backupDirectory = '/bitnami/mariadb/backup'
$restoreDirectory = '/bitnami/mariadb/backup/restore'

Write-Verbose 'Searching for MariaDB slave pods...'
$podFullNamesSlaves = kubectl -n $namespaceCodeDx get pod -l component=slave -o name
if (0 -ne $LASTEXITCODE) {
	Write-Error "Unable to fetch slave pods, kubectl exited with exit code $LASTEXITCODE."
}

if (Test-Path $backupToRestore -PathType Container) {

	Write-Verbose "Copying backup from '$backupToRestore' to '$workDirectory'..."
	Copy-Item -LiteralPath $backupToRestore -Destination $workDirectory -Recurse

} else {

	Write-Verbose "Finding MariaDB slave pod containing backup named $backupToRestore..."
	$podNamesSlaves = @()
	$podNameBackupSlave = ''
	$podFullNamesSlaves | ForEach-Object {

		$podName = $_ -replace 'pod/',''
		$podNamesSlaves = $podNamesSlaves + $podName
		
		if ($podNameBackupSlave -eq '') {
			$backups = kubectl -n $namespaceCodeDx exec -c dbbackup $podName -- ls $backupDirectory
			if (0 -eq $LASTEXITCODE) {
				if ($backups -contains $backupToRestore) {
					$podNameBackupSlave = $podName
					Write-Verbose "Found backup $backupToRestore in pod named $podNameBackupSlave..."
				}
			}
		}
	}
	if ('' -eq $podNameBackupSlave) {
		Write-Error "Unable to find $backupToRestore. Does it exist at $backupDirectory"
	}

	Write-Verbose "Copying backup files from pod $podNameBackupSlave..."
	kubectl -n $namespaceCodeDx cp -c dbbackup $podNameBackupSlave`:/bitnami/mariadb/backup/$backupToRestore $workDirectory
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to copy backup to $workDirectory, kubectl exited with exit code $LASTEXITCODE."
	}
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

Write-Verbose "Copying backup files to master pod named $podNameMaster..."
Copy-DBBackupFiles $namespaceCodeDx $workDirectory $podNameMaster 'mariadb' $restoreDirectory
$podNamesSlaves | ForEach-Object {
	Write-Verbose "Copying backup files to slave pod named $podName..."
	Copy-DBBackupFiles $namespaceCodeDx $workDirectory $podName 'dbbackup' $restoreDirectory
}

Write-Verbose 'Stopping slave database instances...'
$podNamesSlaves | ForEach-Object {
	Write-Verbose "Stopping slave named $podName..."
	Stop-SlaveDB $namespaceCodeDx $podName 'mariadb' $rootPwd
}

Write-Verbose "Stopping $statefulSetMariaDBMaster statefulset replica..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBMaster 0 $waitSeconds

Write-Verbose "Stopping $statefulSetMariaDBSlave statefulset replica(s)..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBSlave 0 $waitSeconds

Write-Verbose "Restoring database backup on pod $podNameMaster..."
Restore-DBBackup 'Master Restore' $waitSeconds $namespaceCodeDx $podNameMaster $mariaDbSecretName
$podNamesSlaves | ForEach-Object {
	Write-Verbose "Restoring database backup on pod $_..."
	Restore-DBBackup "Slave Restore [$_]" $waitSeconds $namespaceCodeDx $_ $mariaDbSecretName
}

Write-Verbose "Starting $statefulSetMariaDBMaster statefulset replica..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBMaster 1 $waitSeconds

Write-Verbose "Starting $statefulSetMariaDBSlave statefulset replica(s)..."
Set-StatefulSetReplicas $namespaceCodeDx $statefulSetMariaDBSlave $statefulSetMariaDBSlaveCount $waitSeconds

Write-Verbose 'Resetting master database...'
$filePos = Get-MasterFilePosAfterReset $namespaceCodeDx 'mariadb' $podNameMaster $rootPwd

Write-Verbose 'Connecting slave database(s)...'
$podNamesSlaves | ForEach-Object {
	Write-Verbose "Restoring slave database pod $_..."
	Start-SlaveDB $namespaceCodeDx $_ 'mariadb' $rootPwd $mariaDbMasterServiceName $filePos
}

Write-Verbose "Starting Code Dx deployment named $deploymentCodeDx..."
Set-DeploymentReplicas  $namespaceCodeDx $deploymentCodeDx 1 $waitSeconds

Write-Host 'Done'
