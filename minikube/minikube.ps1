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

function New-MinikubeCluster([string] $profileName, [string] $k8sVersion, [int] $cpus, [int] $memory) {

	& minikube start -p $profileName --kubernetes-version $k8sVersion --cpus $cpus --memory $memory
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

function Add-DefaultPodSecurityPolicy([string] $pspFile, [string] $roleFile, [string] $roleBindingFile) {

	$psp = @'
apiVersion: policy/v1beta1
kind: PodSecurityPolicy
metadata:
  name: privileged
  annotations:
    seccomp.security.alpha.kubernetes.io/allowedProfileNames: '*'
spec:
  privileged: true
  allowPrivilegeEscalation: true
  allowedCapabilities:
  - '*'
  volumes:
  - '*'
  hostNetwork: true
  hostPorts:
  - min: 0
    max: 65535
  hostIPC: true
  hostPID: true
  runAsUser:
    rule: 'RunAsAny'
  seLinux:
    rule: 'RunAsAny'
  supplementalGroups:
    rule: 'RunAsAny'
  fsGroup:
    rule: 'RunAsAny'
'@

	$psp | out-file $pspFile -Encoding ascii -Force
	& kubectl create -f $pspFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create PodSecurityPolicy. kubectl exited with code $LASTEXITCODE."
	}

	$role = @'
kind: ClusterRole
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: psp:privileged
rules:
- apiGroups: ['policy']
  resources: ['podsecuritypolicies']
  verbs:     ['use']
  resourceNames:
  - privileged
'@

	$role | out-file $roleFile -Encoding ascii -Force
	& kubectl create -f $roleFile
    	if ($LASTEXITCODE -ne 0) {
    		throw "Unable to create PodSecurityPolicy ClusterRole. kubectl exited with code $LASTEXITCODE."
    	}

	$roleBinding = @'
kind: RoleBinding
apiVersion: rbac.authorization.k8s.io/v1
metadata:
  name: psp:privileged-rolebinding
  namespace: kube-system
roleRef:
  kind: ClusterRole
  name: psp:privileged
  apiGroup: rbac.authorization.k8s.io
subjects:
- kind: Group
  apiGroup: rbac.authorization.k8s.io
  name: system:serviceaccounts
'@

	$roleBinding | out-file $roleBindingFile -Encoding ascii -Force
	& kubectl create -f $roleBindingFile
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create default PodSecurityPolicy RoleBinding. kubectl exited with code $LASTEXITCODE."
	}
}

function Start-MinikubeCluster([string] $profileName, [string] $k8sVersion, [switch] $usePsp) {

	# Starts with --network-plugin=cni, optionally with PodSecurityPolicy admission plugin
	if ($usePsp) {
		& minikube start -p $profileName --kubernetes-version $k8sVersion --network-plugin=cni --extra-config=apiserver.enable-admission-plugins=NamespaceLifecycle,LimitRanger,ServiceAccount,DefaultStorageClass,DefaultTolerationSeconds,NodeRestriction,MutatingAdmissionWebhook,ValidatingAdmissionWebhook,ResourceQuota,PodSecurityPolicy
	} else {
		& minikube start -p $profileName --kubernetes-version $k8sVersion --network-plugin=cni
	}

	if ($LASTEXITCODE -ne 0) {
		throw "Unable to start minikube cluster, minikube exited with code $LASTEXITCODE."
	}

	Wait-MinikubeNodeReady 'Start Minikube Cluster' 120 5
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
