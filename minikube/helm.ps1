. (join-path $PSScriptRoot k8s.ps1)

function Add-Helm {

	helm init
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to initialize helm, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment 'Initialize Helm' 300 'kube-system' 'tiller-deploy' 1
}

function Add-HelmRepo([string] $name, [string] $url) {

	helm repo add $name $url
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add helm repository, helm exited with code $LASTEXITCODE."
	}
}

function Invoke-HelmSingleDeployment([string] $message, [string] $namespace, [string] $releaseName, [string] $chartFolder, [string] $valuesFile, [string] $deploymentName, [int] $totalReplicas) {

	helm dependency update $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run dependency update, helm exited with code $LASTEXITCODE."
	}
	Wait-AllRunningPods "Pre-Helm Install: $message" 120

	helm install --name $releaseName --namespace $namespace --values $valuesFile $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm install, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment "Helm Install: $message" 300 $namespace $deploymentName $totalReplicas
}
