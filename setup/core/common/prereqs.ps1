<#PSScriptInfo
.VERSION 1.6.0
.GUID c191448b-25fd-4ec2-980e-e7a8ba85e693
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes support for testing Code Dx prerequisites.

Note: Do not use PowerShell Core v7 syntax in this file because
it will interfere with the PowerShell Core v7 prereq check.
#>

function Test-SetupPreqs([ref] $messages, [switch] $useSealedSecrets, [string] $context, [switch] $checkKubectlVersion) {

	$messages.Value = @()
	$isCore = Test-IsCore
	if (-not $isCore) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core (pwsh)'
	}
	
	if ($isCore -and -not (Test-MinPsMajorVersion 7)) {
		$messages.Value += 'Unable to continue because you must run this script with PowerShell Core 7 or later'
	}
	
	$apps = 'helm','kubectl','openssl','git','keytool'
	if ($useSealedSecrets) {
		$apps += 'kubeseal'
	}

	$appStatus = @{}
	$apps | foreach-object {
		$found = $null -ne (Get-AppCommandPath $_)
		$appStatus[$_] = $found

		if (-not $found) {
			$messages.Value += "Unable to continue because $_ cannot be found. Is $_ installed and included in your PATH?"
		}
		if ($found -and $_ -eq 'helm') {
			$helmVersion = Get-HelmVersionMajorMinor
			if ($null -eq $helmVersion) {
				$messages.Value += 'Unable to continue because helm version was not detected.'
			}
			
			$minimumHelmVersion = 3.1 # required for helm lookup function
			if ($helmVersion -lt $minimumHelmVersion) {
				$messages.Value += "Unable to continue with helm version $helmVersion, version $minimumHelmVersion or later is required"
			}
		}
	}

	$canUseKubectl = $appStatus['kubectl']
	if ($canUseKubectl -and $checkKubectlVersion) {

		if ($context -eq '') {
			$context = Get-KubectlContext
		}
		Set-KubectlContext $context

		$k8sMessages = @()
		if (-not (Test-CodeDxSetupKubernetesVersion ([ref]$k8sMessages))) {
			$messages.Value += $k8sMessages
			$messages.Value += "Note: The prerequisite check used kubectl context '$context'"
		}
	}

	$keytoolJavaSpec = Get-KeytoolJavaSpec
	if ($null -eq $keytoolJavaSpec) {
		$keytoolJavaSpec = '?'
	}
	$requiredJavaSpec = '11'
	if ($requiredJavaSpec -ne $keytoolJavaSpec) {
		$messages.Value += "keytool application is associated with an unsupported java.vm.specification version ($keytoolJavaSpec), update your PATH to run the Java $requiredJavaSpec version of the keytool application"
	}

	$messages.Value.count -eq 0
}

function Test-CodeDxSetupKubernetesVersion ([ref]$k8sMessages) {

	$k8sRequiredMajorVersion = 1
	$k8sMinimumMinorVersion = 19
	$k8sMaximumMinorVersion = 27
	Test-SetupKubernetesVersion $k8sMessages $k8sRequiredMajorVersion $k8sMinimumMinorVersion $k8sMaximumMinorVersion
}