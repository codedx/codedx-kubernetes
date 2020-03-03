. (join-path $PSScriptRoot 'k8s.ps1')

function Add-HelmRepo([string] $name, [string] $url) {

	helm repo add $name $url
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to add helm repository, helm exited with code $LASTEXITCODE."
	}

	helm repo update
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm repo update, helm exited with code $LASTEXITCODE."
	}
}

function Invoke-HelmSingleDeployment([string] $message, [int] $waitSeconds, [string] $namespace, [string] $releaseName, [string] $chartReference, [string] $valuesFile, [string] $deploymentName, [int] $totalReplicas, [string[]] $extraValuesPaths) {

	if (-not (Test-Namespace $namespace)) {
		New-Namespace  $namespace
	}

	if (test-path $chartReference -pathtype container) {
		helm dependency update $chartReference
		if ($LASTEXITCODE -ne 0) {
			throw "Unable to run dependency update, helm exited with code $LASTEXITCODE."
		}
	}

	Wait-AllRunningPods "Pre-Helm Install: $message" $waitSeconds

	# NOTE: Latter values files take precedence over former ones
	$valuesPaths = $extraValuesPaths
	if ($valuesFile -ne '') {
		$valuesPaths = @($valuesFile) + $extraValuesPaths
	}

	$values = @()
	$valuesPaths | ForEach-Object {
		$values = $values + "--values"
		$values = $values + ('"{0}"' -f $_)
	}

	helm upgrade --namespace $namespace --install --reuse-values $releaseName @($values) $chartReference
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run helm upgrade/install, helm exited with code $LASTEXITCODE."
	}
	Wait-Deployment "Helm Upgrade/Install: $message" $waitSeconds $namespace $deploymentName $totalReplicas
}
