. (join-path $PSScriptRoot k8s.ps1)

function Test-MinikubeProfile([string] $profileName) {

	$profileList = & minikube profile list
	$result = $profileList | select-string ('\s{0}\s' -f $profileName)
	$null -ne $result
}

function Test-MinikubeStatus([string] $profileName) {

	& minikube -p $profileName status | out-null
	0 -eq $LASTEXITCODE
}

function New-MinikubeClusterHyperV([string] $profileName, [string] $k8sVersion) {

	$defaultCpus = 4
	$defaultMemory = 13312
	$defaultSwitch = 'Default Switch'

	# Start w/o --network-plugin=cni
	& minikube start -p $profileName --kubernetes-version $k8sVersion --cpus $defaultCpus --memory $defaultMemory
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create k8s cluster. Minikube exited with code $LASTEXITCODE."
	}
}

function Add-NetworkPolicyProvider {

	& kubectl apply -f https://docs.projectcalico.org/v3.9/manifests/calico.yaml
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create k8s cluster. Minikube exited with code $LASTEXITCODE."
	}

	Wait-AllRunningPods 'Add Network Policy' 120 5
}

function Start-MinikubeCluster([string] $profileName, [string] $k8sVersion) {

	# Start w/ --network-plugin=cni
	& minikube start -p $profileName --kubernetes-version $k8sVersion --network-plugin=cni
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to start minikube cluster, minikube exited with code $LASTEXITCODE."
	}

	Wait-MinikubeNodeReady 'Start Minikube Cluster' 120 5
	Wait-AllRunningPods 'Start Minikube Cluster' 120 5
}

function Wait-MinikubeNodeReady([string] $message, [int] $waitSeconds, [int] $sleepSeconds) {

	$timeoutTime = [datetime]::Now.AddSeconds($waitSeconds)
	while ($true) {

		Write-Verbose "Waiting for ready node ($message)..."
		$results = & kubectl get node
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

function New-Certificate([string] $resourceName, [string] $dnsName, [string] $namespace){

	New-Csr $dnsName `
	"$dnsName.$namespace" `
	"$dnsName.$namespace.svc.cluster.local" `
	"$dnsName.conf" `
	"$dnsName.csr" `
	"$dnsName.key"

	New-CsrResource $resourceName "$dnsName.csr" "$dnsName.csrr"
	New-CsrApproval $resourceName

	$certText = Get-Certificate $resourceName
	$caCertText = Get-MinikubeCaCert
	"$certText`n$caCertText" | out-file "$resourceName.pem" -Encoding ascii -Force
}

function Get-MinikubeCaCertPath {
	join-path $HOME '.minikube/ca.crt'
}

function Get-MinikubeCaCert {

	$caCertFile = Get-MinikubeCaCertPath
	[io.file]::ReadAllText($caCertFile)
}

function Stop-MinikubeCluster([string] $profileName) {

	& minikube stop -p $profileName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to stop minikube cluster. Minikube exited with code $LASTEXITCODE."
	}
}
