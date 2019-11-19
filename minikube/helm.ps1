. (join-path $PSScriptRoot k8s.ps1)

function Add-Helm([int] $waitSeconds) {

	helm init
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to initialize helm, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment 'Initialize Helm' $waitSeconds 'kube-system' 'tiller-deploy' 1
}

function Add-HelmRepo([string] $name, [string] $url) {

	helm repo add $name $url
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add helm repository, helm exited with code $LASTEXITCODE."
	}
}

function Invoke-HelmSingleDeployment([string] $message, [int] $waitSeconds, [string] $namespace, [string] $releaseName, [string] $chartFolder, [string] $valuesFile, [string] $deploymentName, [int] $totalReplicas) {

	helm dependency update $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run dependency update, helm exited with code $LASTEXITCODE."
	}
	Wait-AllRunningPods "Pre-Helm Install: $message" $waitSeconds

	helm install --name $releaseName --namespace $namespace --values $valuesFile $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm install, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment "Helm Install: $message" $waitSeconds $namespace $deploymentName $totalReplicas
}
