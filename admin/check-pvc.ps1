<#PSScriptInfo
.VERSION 1.0.0
.GUID 538418ba-21ee-4221-ad23-a3b7e26efcab
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script runs a test using a pod and PVC.
#>

param (
	[string] $namespace = 'default',
    [string] $podName = 'code-dx-test-pod',
    [string] $pvcName = 'code-dx-test-pvc',
	[Parameter(Mandatory=$true)][string] $storageClassName
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

'../setup/core/common/k8s.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

$yaml = @'
apiVersion: v1
kind: PersistentVolumeClaim
metadata:
  name: {3}
  namespace: {0}
spec:
  accessModes:
  - ReadWriteOnce
  resources:
    requests:
      storage: 1Gi
  storageClassName: {2}
---
apiVersion: v1
kind: Pod
metadata:
  name: {1}
  namespace: {0}
spec:
  containers:
    - image: busybox
      name: busybox
      command: ["ls","-la","/var/cdx"]
      volumeMounts:
      - mountPath: "/var/cdx"
        name: code-dx-test-vol
  volumes:
    - name: code-dx-test-vol
      persistentVolumeClaim:
        claimName: {3}
'@ -f $namespace, $podName, $storageClassName, $pvcName

Write-Host "Testing for pod $podName in namespace $namespace."
if (Test-Pod $namespace $podName) {
    Write-Host "Removing pod $podName in namespace $namespace."
    Remove-Pod $namespace $podName
}

$file = [io.path]::GetTempFileName()
$yaml | out-file $file -Encoding ascii

Write-Host "Creating pod $podName in namespace $namespace."
New-NamespacedResource $namespace 'pod' $podName $file
Remove-Item -path $file

Write-Host "Removing pod $podName in namespace $namespace."
Remove-Pod $namespace $podName
Write-Host "Removing pvc $pvcName in namespace $namespace."
Remove-KubernetesPvc $namespace $pvcName

Write-Host 'Done'
