
'./step.ps1',
'../core/common/input.ps1',
'../core/common/codedx.ps1',
'../core/common/helm.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class Abort : Step {

	Abort([ConfigInput] $config) : base(
		[Abort].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		Write-Host 'Setup aborted'
		return $true
	}
}

class Finish : Step {

	Finish([ConfigInput] $config) : base(
		[Finish].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {

		$scriptPath = join-path $PSScriptRoot '../core/setup.ps1'
		$sb = new-object text.stringbuilder($scriptPath)

		'workDir','kubeContextName','kubeApiTargetPort','namespaceCodeDx','releaseNameCodeDx',
		'codeDxDnsName',
		'clusterCertificateAuthorityCertPath',
		'codeDxMemoryReservation','dbMasterMemoryReservation','dbSlaveMemoryReservation','toolServiceMemoryReservation','minioMemoryReservation','workflowMemoryReservation','nginxMemoryReservation',
		'codeDxCPUReservation','dbMasterCPUReservation','dbSlaveCPUReservation','toolServiceCPUReservation','minioCPUReservation','workflowCPUReservation','nginxCPUReservation',
		'codeDxEphemeralStorageReservation','dbMasterEphemeralStorageReservation','dbSlaveEphemeralStorageReservation','toolServiceEphemeralStorageReservation','minioEphemeralStorageReservation','workflowEphemeralStorageReservation','nginxEphemeralStorageReservation',
		'imageCodeDxTomcat','imageCodeDxTools','imageCodeDxToolsMono','imageNewAnalysis','imageSendResults','imageSendErrorResults','imageToolService','imagePreDelete',
		'dockerImagePullSecretName','dockerRegistry','dockerRegistryUser','dockerRegistryPwd',
		'storageClassName',
		'serviceTypeCodeDx',
		'codedxAdminPwd' | ForEach-Object {
			$this.AddParameter($sb, $_)
		}
		'skipTLS','skipPSPs','skipNetworkPolicies','skipIngressEnabled','skipIngressAssumesNginx' | ForEach-Object {
			$this.AddSwitchParameter($sb, $_)
		}

		$this.AddIntParameter($sb, 'codeDxVolumeSizeGiB')

		if (-not $this.config.skipDatabase) {

			'dbVolumeSizeGiB','dbSlaveVolumeSizeGiB','dbSlaveReplicaCount' | ForEach-Object {
				$this.AddIntParameter($sb, $_)
			}
			'mariadbRootPwd','mariadbReplicatorPwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		} else {
			
			'externalDatabaseHost','externalDatabaseName','externalDatabaseUser','externalDatabasePwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
			$this.AddSwitchParameter($sb, 'skipDatabase')
			$this.AddIntParameter($sb, 'externalDatabasePort')

			if (-not $this.config.externalDatabaseSkipTls) {
				$this.AddParameter($sb, 'externalDatabaseServerCert')
			} else {
				$this.AddSwitchParameter($sb, 'externalDatabaseSkipTls')
			}
		}

		if (-not $this.config.skipToolOrchestration) {

			'minioVolumeSizeGiB','toolServiceReplicas' | ForEach-Object {
				$this.AddIntParameter($sb, $_)
			}
			'namespaceToolOrchestration','releaseNameToolOrchestration','toolServiceApiKey','minioAdminPwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		} else {
			$this.AddSwitchParameter($sb, 'skipToolOrchestration')
		}

		if (-not $this.config.skipNginxIngressControllerInstall) {

			'nginxIngressControllerNamespace','nginxIngressControllerLoadBalancerIP' | ForEach-Object { 
				$this.AddParameter($sb, $_)
			}
		} else {
			$this.AddSwitchParameter($sb, 'skipNginxIngressControllerInstall')
		}

		if (-not $this.config.skipLetsEncryptCertManagerInstall) {

			'letsEncryptCertManagerNamespace','letsEncryptCertManagerClusterIssuer','letsEncryptCertManagerRegistrationEmailAddress' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		} else {
			$this.AddSwitchParameter($sb, 'skipLetsEncryptCertManagerInstall')
		}

		$this.AddArrayParameter('ingressAnnotationsCodeDx', $sb, $this.config.ingressAnnotationsCodeDx)
		$this.AddArrayParameter('serviceAnnotationsCodeDx', $sb, $this.config.serviceAnnotationsCodeDx)

		Write-Host "Here's the setup command: "
		Write-Host "pwsh -e $([convert]::ToBase64String([text.encoding]::unicode.getbytes($sb.ToString())))"
		return $true
	}

	[void]AddParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and '' -ne $parameterValue) {
			$sb.appendformat(" -{0} '{1}'", $parameterName, $parameterValue)
		}
	}

	[void]AddIntParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and '' -ne $parameterValue) {
			$sb.appendformat(" -{0} {1}", $parameterName, $parameterValue)
		}
	}

	[void]AddSwitchParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and $parameterValue) {
			$sb.appendformat(" -{0}", $parameterName)
		}
	}

	[void]AddArrayParameter([string] $parameterName, [text.stringbuilder] $sb, [string[]] $parameterValue) {

		if ($parameterValue.count -eq 0) {
			return
		}

		$escapedParameterValues = @()
		$escapedParameterValues += $parameterValue | ForEach-Object {
			$_.Replace("'", "''")
		}
		$sb.AppendFormat(" -{0} @('{1}')", $parameterName, ([string]::join("','", $escapedParameterValues)))
	}
}

