. (join-path $PSScriptRoot k8s.ps1)

function Test-MinikubeProfile([string] $profileName, [string] $vmDriver, [string] $k8sVersion) {

	$profileList = minikube profile list
	$result = $profileList | select-string ('\s{0}\s+\|\s+{1}\s+.+\s+{2}\s+\|' -f [regex]::escape($profileName),[regex]::escape($vmDriver),[regex]::escape($k8sVersion))
	$null -ne $result
}

function Test-MinikubeStatus([string] $profileName) {

	minikube -p $profileName status | out-null
	0 -eq $LASTEXITCODE
}

function New-MinikubeCluster([string] $profileName, [string] $k8sVersion, [string] $vmDriver, [int] $cpus, [string] $memory, [string] $diskSize, [string[]] $extraConfig) {

	Write-Verbose "Creating new minikube instance ($profileName) with the following parameters:`n  driver=$vmDriver`n  k8s=$k8sversion`n  cpus=$cpus`n  memory=$memory`n  disk=$diskSize"
	minikube start --vm-driver=$vmDriver -p $profileName --kubernetes-version $k8sVersion --cpus $cpus --memory $memory --disk-size $diskSize @($extraConfig)
	
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create k8s cluster. Minikube exited with code $LASTEXITCODE."
	}
}

function Add-CalicoNetworkPolicyProvider([string] $waitSeconds) {

	kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add Calico. kubectl exited with code $LASTEXITCODE."
	}

	Wait-AllRunningPods 'Add Network Policy' $waitSeconds
}

function Add-IngressAddon([string] $profileName, [int] $waitSeconds) {

	minikube -p $profileName addons enable ingress
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add ingress addon. Minikube exited with code $LASTEXITCODE."
	}

	Wait-Deployment 'Ingress Addon' $waitSeconds 'kube-system' 'nginx-ingress-controller' 1
}

function Start-MinikubeCluster([string] $profileName, [string] $k8sVersion, [string] $vmDriver, [int] $waitSeconds, [switch] $usePsp, [switch] $useNetworkPolicy, [string[]] $extraConfig) {

	$pspConfig = ''
	if ($usePsp) {
		$pspConfig = '--extra-config=apiserver.enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,PodSecurityPolicy'
	}

	$cniConfig = ''
	if ($useNetworkPolicy) {
		$cniConfig = '--network-plugin=cni'
	}

	minikube start -p $profileName --kubernetes-version $k8sVersion --vm-driver $vmDriver $cniConfig $pspConfig @($extraConfig)

	if ($LASTEXITCODE -ne 0) {
		throw "Unable to start minikube cluster, minikube exited with code $LASTEXITCODE."
	}

	Wait-MinikubeNodeReady 'Start Minikube Cluster' $waitSeconds
}

function Wait-MinikubeNodeReady([string] $message, [int] $waitSeconds) {

	$sleepSeconds = [math]::min(60, ($waitSeconds * .05))
	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		Write-Verbose "Waiting for ready node ($message)..."
		$results = kubectl get node
		if ($null -ne ($results | select-string 'minikube\s+Ready')) {
			Write-Verbose "Node is ready ($message)"
			break
		}

		if ([datetime]::now -gt $timeoutTime) {
			throw "Unable to continue because a timeout occurred while waiting for the minikube node to be in a Ready state ($message)"
		}
		Write-Verbose "The node is not ready. Another check will occur in $sleepSeconds seconds ($message)."
		start-sleep -seconds $sleepSeconds
	}
}

function Get-MinikubeCaCertPath {
	join-path $HOME '.minikube/ca.crt'
}

function Stop-MinikubeCluster([string] $profileName) {

	minikube stop -p $profileName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to stop minikube cluster. Minikube exited with code $LASTEXITCODE."
	}
}

function New-ReadWriteOncePersistentVolume([int] $sizeInGiB) {

	$pvID = [guid]::NewGuid().ToString()
	$pvPath = '/srv/minikube-pvs/pv-{0}' -f $pvID

	Write-Verbose "Creating directory '$pvPath' for a PV with size $($sizeInGiB)GiB..."
	New-Item -ItemType Directory -Path $pvPath

	if ($IsLinux) {
		Write-Verbose "Changing mode of '$pvPath' to 777..."
		/bin/chmod 777 $pvPath
	}

	$pvDefinition = @'
apiVersion: v1
kind: PersistentVolume
metadata:
  name: pv-{0}
spec:
  accessModes:
  - ReadWriteOnce
  capacity:
    storage: {1}Gi
  hostPath:
    path: {2}
    type: ""
  persistentVolumeReclaimPolicy: Delete
  storageClassName: standard
  volumeMode: Filesystem
'@ -f $pvID, $sizeInGiB, $pvPath

	$pvTempFile = New-TemporaryFile
	$pvDefinition | Out-File -Encoding ascii -LiteralPath $pvTempFile.FullName

	Write-Verbose "Applying PV from file $($pvTempFile.FullName)..."
	kubectl apply -f $pvTempFile.FullName
}
