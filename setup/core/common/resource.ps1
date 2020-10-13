<#PSScriptInfo
.VERSION 1.0.0
.GUID 0c9bd537-7359-4ebb-a64c-cf1693ccc4f9
.AUTHOR Code Dx
#>

function Set-ResourceDirectory([string] $kind) {

	$directory = "./GitOps/$kind"
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

function New-CertificateConfigMapResource([string] $namespace, [string] $name, [string] $certFile,
	[switch] $useGitOps) {

	$ccm = New-CertificateConfigMap $namespace $name $certFile -dryRun:$useGitOps
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
    }

    Get-ChildItem $sealedSecretPath
}

function New-HelmRelease(
	[Parameter(Position=0)] [Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string] $name,
	[Parameter(Position=1)] [Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string]   $namespace,
	[Parameter(Position=2)] [Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string]   $releaseName,
	[Parameter(ParameterSetName='GitChart')]
	[string]   $chartGit,
	[Parameter(ParameterSetName='GitChart')]
	[string]   $chartRef,
	[Parameter(ParameterSetName='GitChart')]
	[string]   $chartPath,
	[Parameter(ParameterSetName='RepoChart')]
	[string]   $chartRepository,
	[Parameter(ParameterSetName='RepoChart')]
	[string]   $chartName,
	[Parameter(ParameterSetName='RepoChart')]
	[string]   $chartVersion,
	[Parameter(ParameterSetName='GitChart')] [Parameter(ParameterSetName='RepoChart')]
	[string[]] $valuesConfigMapNames) {

    $chart = ''
    if ('' -ne $chartGit) {
		$chart = @'
    git: {0}
    ref: {1}
    path: {2}
'@ -f $chartGit,$chartRef,$chartPath
    } else {
		$chart = @'
    repository: {0}
    name: {1}
    version: {2}
'@ -f $chartRepository,$chartName,$chartVersion
    }

    $helmRelease = @'
apiVersion: helm.fluxcd.io/v1
kind: HelmRelease
metadata:
  name: {0}
  namespace: {1}
  annotations:
spec:
  releaseName: {2}
  chart:
{3}
  valuesFrom:
'@ -f $name,$namespace,$releaseName,$chart

    $valuesConfigMapNames | ForEach-Object {

        $valuesFromTemplate = @'

  - configMapKeyRef:
      name: {0}
      namespace: {1}
      key: values.yaml
      optional: false
'@ -f $_,$namespace

        $helmRelease += $valuesFromTemplate
    }

    New-ResourceFile 'HelmRelease' $namespace $name $helmRelease
}
