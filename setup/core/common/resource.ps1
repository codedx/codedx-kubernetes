<#PSScriptInfo
.VERSION 1.4.1
.GUID 0c9bd537-7359-4ebb-a64c-cf1693ccc4f9
.AUTHOR Code Dx
#>

function Get-ResourceDirectoryPath([string] $kind) {
	return "./GitOps/$kind"
}

function Set-ResourceDirectory([string] $kind) {

	$directory = Get-ResourceDirectoryPath $kind
	if (Test-Path $directory -PathType Container) {
		New-Object IO.DirectoryInfo($directory)
	} else {
		New-Item $directory -ItemType Directory
	}
}

function New-ResourceFile([string] $kind, [string] $namespace, [string] $name, [string[]] $resourceFile) {

	$directory = Set-ResourceDirectory $kind
	$kind = $kind.ToLower()
	$filename = $namespace -eq '' ? "$kind-$name.yaml" : "$kind-$namespace-$name.yaml"
	$resourcePath = join-path $directory $filename

	$resourceFile | Out-File $resourcePath -Encoding ascii -Force
	Get-ChildItem $resourcePath
}

function New-SealedSecretFile([io.fileinfo] $secretFileInfo,
	[string] $sealedSecretsNamespace,
	[string] $sealedSecretsControllerName,
	[string] $sealedSecretsPublicKeyPath,
	[switch] $keepSecretFile) {

	$kind = 'SealedSecret'
	$directory = Set-ResourceDirectory $kind
	$kind = $kind.ToLower()
	$filename = "$kind-$namespace-$name.yaml"
	$resourcePath = join-path $directory $filename

	New-SealedSecret $secretFileInfo $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath $resourcePath -keepSecretFile:$keepSecretFile
}

function New-NamespaceResource([string] $namespace, [Tuple`2[string,string]] $label,
	[switch] $useGitOps) {

	$ns = New-Namespace $namespace $label -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $ns
	}
	New-ResourceFile 'Namespace' '' $namespace $ns
}

function New-PriorityClassResource([string] $name, [int] $values,
	[switch] $useGitOps) {

	$pc = New-PriorityClass $name $values -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $pc
	}
	New-ResourceFile 'PriorityClass' '' $name $pc
}

function New-CertificateSecretResource([string] $namespace, [string] $name, [string] $certFile, [string] $keyFile,
	[switch] $useGitOps,
	[switch] $useSealedSecrets,	[string] $sealedSecretsNamespace, [string] $sealedSecretsControllerName, [string] $sealedSecretsPublicKeyPath) {

	$cs = New-CertificateSecret $namespace $name $certFile $keyFile -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $cs
	}

	New-SecretResourceFile $namespace $name $cs -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
}

function New-CertificateConfigMapResource([string] $namespace, [string] $name, [string] $certFile, [string] $certFilenameInConfigMap, 
	[switch] $useGitOps) {

	$ccm = New-CertificateConfigMap $namespace $name $certFile $certFilenameInConfigMap -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $ccm
	}
	New-ResourceFile 'ConfigMap' $namespace $name $ccm
}

function New-GenericSecretResource([string] $namespace, [string] $name, [hashtable] $keyValues = @{}, [hashtable] $fileKeyValues = @{},
	[switch] $useGitOps,
	[switch] $useSealedSecrets,	[string] $sealedSecretsNamespace, [string] $sealedSecretsControllerName, [string] $sealedSecretsPublicKeyPath) {

	$s = New-GenericSecret $namespace $name $keyValues $fileKeyValues -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $s
	}

	New-SecretResourceFile $namespace $name $s -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
}

function New-DockerImagePullSecretResource([string] $namespace, [string] $name, [string] $dockerRegistry, [string] $dockerRegistryUser,	[string] $dockerRegistryPwd,
	[switch] $useGitOps,
	[switch] $useSealedSecrets,	[string] $sealedSecretsNamespace, [string] $sealedSecretsControllerName, [string] $sealedSecretsPublicKeyPath) {
	
	$s = New-ImagePullSecret $namespace $name $dockerRegistry $dockerRegistryUser $dockerRegistryPwd -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $s
	}

	New-SecretResourceFile $namespace $name $s -useSealedSecrets:$useSealedSecrets $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
}

function New-SecretResourceFile([string] $namespace, [string] $name, [string[]] $resourceFile,
	[switch] $useSealedSecrets,	[string] $sealedSecretsNamespace, [string] $sealedSecretsControllerName, [string] $sealedSecretsPublicKeyPath) {

	$file = New-ResourceFile 'Secret' $namespace $name $resourceFile
	if ($useSealedSecrets) {
		return New-SealedSecretFile $file $sealedSecretsNamespace $sealedSecretsControllerName $sealedSecretsPublicKeyPath
	}
	return $file
}

function New-ConfigMapResource([string] $namespace, [string] $name, [hashtable] $keyValues = @{}, [hashtable] $fileKeyValues = @{},
	[switch] $useGitOps) {

	$cm = New-ConfigMap $namespace $name $keyValues $fileKeyValues -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $cm
	}
	New-ResourceFile 'ConfigMap' $namespace $name $cm
}

function New-NamespacedResourceFromYaml([string] $namespace, [string] $resourceKind, [string] $resourceName, [string] $yamlPath,
	[switch] $useGitOps) {

	if ($useGitOps) {
		$resource = Get-Content $yamlPath
		return New-ResourceFile $resourceKind $namespace $resourceName $resource
	}

	New-NamespacedResource $namespace $resourceKind $resourceName $yamlPath
}

function Set-CustomResourceDefinitionResource([string] $name, [string] $path,
	[switch] $useGitOps) {

	$crd = Set-NonNamespacedResource $path 'crd' -dryRun:$useGitOps
	if (-not $useGitOps) {
		return $crd
	}
	New-ResourceFile 'CustomResourceDefinition' '' $name $crd
}

function New-SealedSecret([io.fileinfo] $secretFileInfo,
    [string] $sealedSecretsNamespace,
    [string] $sealedSecretsControllerName,
    [string] $sealedSecretsPublicKeyPath,
    [string] $sealedSecretPath,
    [switch] $keepSecretFile) {

    Get-Content $secretFileInfo.FullName | kubeseal --controller-namespace=$sealedSecretsNamespace --controller-name=$sealedSecretsControllerName --format yaml --cert $sealedSecretsPublicKeyPath > $sealedSecretPath
    if (0 -ne $LASTEXITCODE) {
        throw "Unable to create sealed secret for specified input ($sealedSecretPath)"
    }

    if (-not $keepSecretFile) {
        $secretFileInfo.Delete()

		$secretFileDirectory = Get-ResourceDirectoryPath 'Secret'
		if ((Get-ChildItem $secretFileDirectory).Count -eq 0) {
			Remove-Item $secretFileDirectory
		}
    }

    Get-ChildItem $sealedSecretPath
}

function New-HelmOperatorGitSource(
	[string] $chartGit,
	[string] $chartRef,
	[string] $chartPath) {

	return @"
    git: $chartGit
    ref: $chartRef
    path: $chartPath
"@
}

function New-HelmOperatorChartSource(
	[string] $chartRepository,
	[string] $chartName,
	[string] $chartVersion) {

	return @"
    repository: $chartRepository
    name: $chartName
    version: $chartVersion
"@
}

function New-HelmControllerGitSource(
	[string] $chartGitName,
	[string] $chartRef,
	[string] $chartPath) {

	return @"
    spec:
      chart: $chartPath
      sourceRef:
        kind: GitRepository
        name: $chartGitName-$chartRef
"@
}

function New-HelmControllerChartSource(
	[string] $name,
	[string] $chartName,
	[string] $chartVersion) {

	return @"
    spec:
      chart: $chartName
      sourceRef:
        kind: HelmRepository
        name: $name
      version: '$chartVersion'
"@	
}

function New-HelmOperatorConfigMapValues(
	[string] $configMapName
) {
	return @"

  - configMapKeyRef:
      name: $_
"@
}

function New-HelmControllerConfigMapValues(
	[string] $configMapName
) {
	return @"

  - kind: ConfigMap
    name: $_
"@
}

function New-GitRepository(
	[string] $name,
	[string] $namespace,
	[string] $gitURL,
	[string] $gitRef
) {

	return @"
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: GitRepository
metadata:
  name: $name-$gitRef
  namespace: $namespace
spec:
  interval: 1m0s
  ref:
    tag: $gitRef
  url: $gitURL
"@
}

function New-HelmRepository(
	[string] $name,
	[string] $namespace,
	[string] $chartRepository
) {

	return @"
apiVersion: source.toolkit.fluxcd.io/v1beta1
kind: HelmRepository
metadata:
  name: $name
  namespace: $namespace
spec:
  interval: 1m0s
  url: $chartRepository
"@
}

function New-HelmRelease(
	[Parameter(Position=0)] [Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string]    $name,
	[Parameter(Position=1)] [Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string]    $namespace,
	[Parameter(Position=2)] [Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string]    $releaseName,
	[Parameter(ParameterSetName='GitChart')]
	[string]    $chartGitName,
	[Parameter(ParameterSetName='GitChart')]
	[string]    $chartGit,
	[Parameter(ParameterSetName='GitChart')]
	[string]    $chartRef,
	[Parameter(ParameterSetName='GitChart')]
	[string]    $chartPath,
	[Parameter(ParameterSetName='RepoChart')]
	[string]    $chartRepository,
	[Parameter(ParameterSetName='RepoChart')]
	[string]    $chartName,
	[Parameter(ParameterSetName='RepoChart')]
	[string]    $chartVersion,
	[Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string[]]  $valuesConfigMapNames,
	[Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[hashtable] $dockerImageNames,
	[Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[switch]    $useHelmController) {

	$isGitChart = '' -ne $chartGit
	$chartSource = ''

	if ($useHelmController) {

		if ($isGitChart) {

			$gitRepository = New-GitRepository $chartGitName $namespace $chartGit $chartRef
			New-ResourceFile 'GitRepository' $namespace "$chartGitName-$chartRef" $gitRepository

			$chartSource = New-HelmControllerGitSource $chartGitName $chartRef $chartPath
		} else {

			$chartRepository = New-HelmRepository $name $namespace $chartRepository
			New-ResourceFile 'HelmRepository' $namespace $name $chartRepository

			$chartSource = New-HelmControllerChartSource $name $chartName $chartVersion
		}
		
	} else {

		if ($isGitChart) {
			$chartSource = New-HelmOperatorGitSource $chartGit $chartRef $chartPath
		} else {
			$chartSource = New-HelmOperatorChartSource $chartRepository $chartName $chartVersion
		}
	}
	
	$values = ''
	if ($dockerImageNames.Count -gt 0) {

		$values = @'
  values:
'@
		$dockerImageNames.Keys | Sort-Object | ForEach-Object {

			$values += @"

    $_`: $($dockerImageNames[$_])
"@
		}
	}

	$valuesFrom = ''
	if ($valuesConfigMapNames.Count -gt 0) {

		$valuesFrom = @'
  valuesFrom:
'@
 		$valuesConfigMapNames | ForEach-Object {
			$valuesFrom += $useHelmController ? (New-HelmControllerConfigMapValues $_) : (New-HelmOperatorConfigMapValues $_)
		}
	}

    $helmRelease = @'
apiVersion: {0}
kind: HelmRelease
metadata:
  name: {1}
  namespace: {2}
spec:
  releaseName: {3}
  chart:
{4}
{5}
{6}
{7}
'@ -f 
	($useHelmController ? 'helm.toolkit.fluxcd.io/v2beta1' : 'helm.fluxcd.io/v1'),
	$name,$namespace,$releaseName,$chartSource,$valuesFrom,$values,
	($useHelmController ? '  interval: 1m0s' : '')

    New-ResourceFile 'HelmRelease' $namespace $name $helmRelease
}
