. (join-path $PSScriptRoot k8s.ps1)

function Add-HelmRepo([string] $name, [string] $url) {

	helm repo add $name $url
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add helm repository, helm exited with code $LASTEXITCODE."
	}
}

function Invoke-HelmSingleDeployment([string] $message, [int] $waitSeconds, [string] $namespace, [string] $releaseName, [string] $chartFolder, [string] $valuesFile, [string] $deploymentName, [int] $totalReplicas, [string[]] $extraValuesPaths) {

	helm dependency update $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run dependency update, helm exited with code $LASTEXITCODE."
	}
	Wait-AllRunningPods "Pre-Helm Install: $message" $waitSeconds

	$extraValues = @()
	$extraValuesPaths | ForEach-Object {
		$extraValues = $extraValues + "--values"
		$extraValues = $extraValues + ('"{0}"' -f $_)
	}

	helm install $releaseName --namespace $namespace --values $valuesFile @($extraValues) $chartFolder
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm install, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment "Helm Install: $message" $waitSeconds $namespace $deploymentName $totalReplicas
}