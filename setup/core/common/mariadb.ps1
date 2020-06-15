<#PSScriptInfo
.VERSION 1.0.2
.GUID d7edc525-a26e-4f80-b65b-262a0e56422e
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for MariaDB-related tasks.
#>

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

function Copy-DBBackupFiles([string] $namespace, 
	[string] $backupFiles,
	[string] $podName,
	[string] $containerName,
	[string] $destinationPath) {

	kubectl -n $namespace exec -c $containerName $podName -- rm -Rf $destinationPath
	kubectl -n $namespace exec -c $containerName $podName -- mkdir -p $destinationPath
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to create directory to store backup files, kubectl exited with exit code $LASTEXITCODE."
	}

	kubectl -n $namespace cp   -c $containerName $backupFiles $podName`:$destinationPath
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to copy backup files to pod, kubectl exited with exit code $LASTEXITCODE."
	}
}

function Stop-SlaveDB([string] $namespace, 
	[string] $podName,
	[string] $containerName,
	[string] $rootPwd) {

	kubectl -n $namespace exec -c $containerName $podName -- mysqladmin -uroot --password=$rootPwd stop-slave
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to stop DB slave, kubectl exited with exit code $LASTEXITCODE."
	}
}

function Restore-DBBackup([string] $message,
	[int] $waitSeconds,
	[string] $namespace,
	[string] $podName,
	[string] $rootPwdSecretName) {

	if (Test-KubernetesJob $namespace $podName) {
		Remove-KubernetesJob $namespace $podName
	}
	
	$job = @'
apiVersion: batch/v1
kind: Job
metadata:
  name: '{1}'
  namespace: '{0}'
spec:
  template:
    spec:
      containers:
      - name: restoredb
        image: ssalas/codedx-dbrestore:v1.0.1
        imagePullPolicy: Always
        command: ["/bin/bash"]
        args: ["-c", "/home/sdb/restore"]
        volumeMounts:
        - mountPath: /bitnami/mariadb
          name: data
        - mountPath: /home/sdb/cfg
          name: rootpwd
          readOnly: true
      restartPolicy: Never
      securityContext:
        fsGroup: 1001
        runAsUser: 1001
      volumes:
      - name: data
        persistentVolumeClaim:
          claimName: 'data-{1}'
      - name: rootpwd
        secret:
          secretName: '{2}'
          items:
          - key: mariadb-root-password
            path: .passwd
'@ -f $namespace, $podName, $rootPwdSecretName

	$file = [io.path]::GetTempFileName()
	$job | out-file $file -Encoding ascii

	kubectl apply -f $file
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to create restore job from file $file, kubectl exited with exit code $LASTEXITCODE."
	}
	remove-item -path $file

	Wait-JobSuccess $message $waitSeconds $namespace $podName

	Remove-KubernetesJob $namespace $podName
}

function Get-MasterFilePosAfterReset([string] $namespace,
	[string] $containerName,
	[string] $podName,
	[string] $rootPwd) {

	$cmd = 'RESET MASTER;FLUSH TABLES WITH READ LOCK;SHOW MASTER STATUS \G;UNLOCK TABLES;'
	$output = kubectl -n $namespace exec -c $containerName $podName -- mysql -uroot --password=$rootPwd -e $cmd
	if (0 -ne $LASTEXITCODE) {
	  throw "Unable to get file position from master, kubectl exited with exit code $LASTEXITCODE."
	}

	$filePos = @{}
	$fileMatch = $output | select-string -pattern 'File:\s(?<file>.+)$'
	$filePos.file = $fileMatch.matches.Groups[1].value

	$positionMatch = $output | select-string -pattern 'Position:\s(?<file>\d+)$'
	$filePos.position = $positionMatch.matches.Groups[1].value

	$filePos
}

function Start-SlaveDB([string] $namespace, 
	[string] $podName,
	[string] $containerName,
	[string] $rootPwd,
	[string] $mariaDbServiceName,
	$filePos) {

	$cmd = "RESET SLAVE; CHANGE MASTER TO MASTER_LOG_FILE='$($filePos.file)',MASTER_LOG_POS=$($filePos.position),MASTER_HOST='$mariaDbServiceName',MASTER_USER='root',MASTER_PASSWORD='$rootPwd'; START SLAVE; SHOW SLAVE STATUS \G;"

	kubectl -n $namespace exec -c $containerName $podName -- mysql -uroot --password=$rootPwd -e $cmd
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to start DB slave, kubectl exited with exit code $LASTEXITCODE."
	}
}

function Get-DatabaseUrl([string] $databaseHost, [int] $databasePort,
	[string] $databaseName,
	[string] $databaseCertPath,
	[switch] $databaseSkipTls) {

	$url = "jdbc:mysql://$databaseHost"
	if ($databasePort -ne 3306) {
		$url = "$url`:$databasePort"
	}

	$url = "$url/$databaseName"

	if (-not $databaseSkipTls) {

		if ($databaseCertPath -eq '' -or -not (Test-Path $databaseCertPath -PathType Leaf)) {
			throw "Using a One-Way SSL/TLS configuration requires a server certificate"
		}
		$url = "$url`?useSSL=true&requireSSL=true"
	}
	$url
}