<#PSScriptInfo
.VERSION 1.3.0
.GUID d7edc525-a26e-4f80-b65b-262a0e56422e
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for MariaDB-related tasks.
#>

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

function Restore-DBBackup([string] $message,
	[int] $waitSeconds,
	[string] $namespace,
	[string] $podName,
	[string] $rootPwdSecretName,
	[string] $serviceAccountName,
	[string] $imageDatabaseRestore,
	[string] $imageDatabaseRestorePullSecretName) {

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
      imagePullSecrets: {5}
      containers:
      - name: restoredb
        image: {4}
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
      serviceAccountName: {3}
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
'@ -f $namespace, $podName, $rootPwdSecretName, $serviceAccountName, 
$imageDatabaseRestore, ($imageDatabaseRestorePullSecretName -eq '' ? '[]' : "[ {name: '$imageDatabaseRestorePullSecretName'} ]")

	$file = [io.path]::GetTempFileName()
	$job | out-file $file -Encoding ascii

	kubectl create -f $file
	if (0 -ne $LASTEXITCODE) {
		Write-Error "Unable to create restore job from file $file, kubectl exited with exit code $LASTEXITCODE."
	}
	remove-item -path $file

	Wait-JobSuccess $message $waitSeconds $namespace $podName

	Remove-KubernetesJob $namespace $podName
}
