
'./step.ps1',
'../core/common/codedx.ps1' | ForEach-Object {
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

	static [string] hidden $description = @'
You have now specified what's necessary to run the core setup script.

At this point, you can launch the script to install Code Dx 
components based on the configuration data you entered. Alternatively, you 
can save the script command line to a file to run it at a later time.
	
Note: If you need to add setup.ps1 parameters such as custom codedx.props 
settings, save the setup script command to a file and include any extra 
parameters. Refer to the following URL for details on setup.ps1 parameters: 
https://github.com/codedx/codedx-kubernetes/tree/master/setup/core
'@
		
	Finish([ConfigInput] $config) : base(
		[Finish].Name, 
		$config,
		'Next Step',
		[Finish]::description,
		'What would you like to do next?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$options = @(
			[tuple]::create('Save and &Run Script', 'Run the setup script after saving the script command a file'),
			[tuple]::create('&Save Script', 'Save the setup script to run later')
		)

		return new-object MultipleChoiceQuestion($prompt, $options, -1)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$scriptPath = join-path $PSScriptRoot '../core/setup.ps1'
		$sb = new-object text.stringbuilder($scriptPath)

		'workDir','kubeContextName','kubeApiTargetPort','namespaceCodeDx','releaseNameCodeDx',
		'codeDxDnsName',
		'clusterCertificateAuthorityCertPath',
		'codeDxMemoryReservation','dbMasterMemoryReservation','dbSlaveMemoryReservation','toolServiceMemoryReservation','minioMemoryReservation','workflowMemoryReservation',
		'codeDxCPUReservation','dbMasterCPUReservation','dbSlaveCPUReservation','toolServiceCPUReservation','minioCPUReservation','workflowCPUReservation',
		'codeDxEphemeralStorageReservation','dbMasterEphemeralStorageReservation','dbSlaveEphemeralStorageReservation','toolServiceEphemeralStorageReservation','minioEphemeralStorageReservation','workflowEphemeralStorageReservation',
		'imageCodeDxTomcat','imageCodeDxTools','imageCodeDxToolsMono','imageNewAnalysis','imageSendResults','imageSendErrorResults','imageToolService','imagePrepare','imagePreDelete',
		'imageCodeDxTomcatInit','imageMariaDB','imageMinio','imageWorkflowController','imageWorkflowExecutor',
		'dockerImagePullSecretName','dockerRegistry','dockerRegistryUser',
		'redirectDockerHubReferencesTo',
		'storageClassName',
		'serviceTypeCodeDx',
		'caCertsFilePath',
		'ingressTlsSecretNameCodeDx',
		'backupType','namespaceVelero','backupScheduleCronExpression',
		'csrSignerNameCodeDx','csrSignerNameToolOrchestration' | ForEach-Object {
			$this.AddParameter($sb, $_)
		}
		'backupDatabaseTimeoutMinutes','backupTimeToLiveHours' | ForEach-Object {
			$this.AddPositiveIntParameter($sb, $_)
		}

		$runNow = ([MultipleChoiceQuestion]$question).choice -eq 0
		$useGitOps = $this.config.UseGitOps()

		if ($useGitOps) {
			'useHelmOperator','useHelmController','useHelmCommand','useHelmManifest','skipSealedSecrets' | ForEach-Object {
				$this.AddSwitchParameter($sb, $_)
			}
			'sealedSecretsNamespace','sealedSecretsControllerName','sealedSecretsPublicKeyPath' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		}

		'dockerRegistryPwd','codedxAdminPwd','caCertsFilePwd','caCertsFileNewPwd','codedxDatabaseUserPwd' | ForEach-Object {
			$this.AddParameter($sb, $_)
		}

		'skipTLS','skipServiceTLS','skipPSPs','skipNetworkPolicies','skipIngressEnabled','useSaml','createSCCs','skipUseRootDatabaseUser' | ForEach-Object {
			$this.AddSwitchParameter($sb, $_)
		}

		if ($this.config.useSaml) {
			'samlIdentityProviderMetadataPath','samlAppName' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}

			'samlKeystorePwd','samlPrivateKeyPwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		}

		'codeDxVolumeSizeGiB','codeDxTlsServicePortNumber' | ForEach-Object {
			$this.AddIntParameter($sb, $_)
		}
		'codeDxNodeSelector','codeDxNoScheduleExecuteToleration' | ForEach-Object {
			$this.AddKeyValueParameter($sb, $_)
		}

		if (-not $this.config.skipDatabase) {

			$this.AddIntParameter($sb, 'dbVolumeSizeGiB')
			if ($this.config.dbSlaveReplicaCount -gt 0) {
				
				'dbSlaveVolumeSizeGiB','dbSlaveReplicaCount' | ForEach-Object {
					$this.AddIntParameter($sb, $_)
				}
				'subordinateDatabaseNodeSelector','subordinateDatabaseNoScheduleExecuteToleration' | ForEach-Object {
					$this.AddKeyValueParameter($sb, $_)
				}
			} else {
				$this.AddIntParameter($sb, 'dbSlaveReplicaCount')
			}

			'masterDatabaseNodeSelector','masterDatabaseNoScheduleExecuteToleration' | ForEach-Object {
				$this.AddKeyValueParameter($sb, $_)
			}

			'mariadbRootPwd','mariadbReplicatorPwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		} else {
			
			'externalDatabaseHost','externalDatabaseName' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}

			'externalDatabaseUser','externalDatabasePwd' | ForEach-Object {
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

			if ($this.config.skipMinIO) {

				$this.AddSwitchParameter($sb, 'skipMinIO')
				$this.AddSwitchParameter($sb, 'externalWorkflowStorageEndpointSecure')

				'externalWorkflowStorageEndpoint',
				'externalWorkflowStorageUsername','externalWorkflowStoragePwd',
				'externalWorkflowStorageBucketName','externalWorkflowStorageCertChainPath' | ForEach-Object {
					$this.AddParameter($sb, $_)
				}
			} else {
				$this.AddIntParameter($sb, 'minioVolumeSizeGiB')
			}

			$this.AddIntParameter($sb, 'toolServiceReplicas')
			'namespaceToolOrchestration','releaseNameToolOrchestration' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
			'toolServiceNodeSelector','toolServiceNoScheduleExecuteToleration',
			'minioNodeSelector','minioNoScheduleExecuteToleration',
			'workflowControllerNodeSelector','workflowControllerNoScheduleExecuteToleration',
			'toolNodeSelector','toolNoScheduleExecuteToleration' | ForEach-Object {
				$this.AddKeyValueParameter($sb, $_)
			}

			'toolServiceApiKey','minioAdminPwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		} else {
			$this.AddSwitchParameter($sb, 'skipToolOrchestration')
		}

		$this.AddArrayParameter($sb, 'extraCodeDxTrustedCaCertPaths')

		'ingressAnnotationsCodeDx','serviceAnnotationsCodeDx' | ForEach-Object {
			$this.AddHashtableParameter($sb, $_)
		}

		$setupCmdLine = $sb.ToString()

		$this.PrintNotes()

		$this.SaveScript($setupCmdLine)
		if ($runNow) {
			if (-not ($this.RunNow($setupCmdLine))) {
				Write-Host 'The setup script failed to run successfully.'
			}
		}
		return $true
	}

	[void]PrintNotes() {

		if ($this.config.notes.count -eq 0) {
			return
		}

		Write-Host "`n---`nInstallation Notes:`n"
		$notesPrinted = New-Object Collections.Generic.HashSet[string]

		$allNotes = @()
		$this.config.notes.keys | ForEach-Object {
			$note = $this.config.notes[$_]
			if (-not $notesPrinted.Contains($note)) {
				$notesPrinted.Add($note) | Out-Null
				$allNotes += $note
			}
		}
		$allNotes | sort | ForEach-Object {
			Write-Host $_
		}
		Write-Host "---`n"
	}

	[bool]RunNow([string] $setupCmdLine) {

		Read-Host "Press Enter to run the script now"
		Write-Host "`nRunning setup command..."

		# Pause after running the script to show output that might appear in a new window
		$pauseCmd = "Write-Host 'Press Enter to exit...' -NoNewline; Read-Host"

		$cmd = ([convert]::ToBase64String([text.encoding]::unicode.getbytes("$setupCmdLine; $pauseCmd")))
		$process = Start-Process pwsh '-e',$cmd -Wait -PassThru
		if ($process.ExitCode -ne 0) {
			return $false
		}
		return $true
	}

	[void]SaveScript([string] $setupCmdLine) {

		$setupScriptPath = join-path $this.config.workDir 'run-setup.ps1'
		Write-Host "`nWriting $setupScriptPath..."
		$setupCmdLine | Out-File $setupScriptPath

		Write-Host "`nRun the script at any time with this command: pwsh ""$setupScriptPath""`n"
	}

	[void]AddParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and '' -ne $parameterValue) {
			$sb.appendformat(" -{0} '{1}'", $parameterName, ($parameterValue -replace "'","''"))
		}
	}

	[void]AddIntParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue) {
			$sb.appendformat(" -{0} {1}", $parameterName, $parameterValue)
		}
	}

	[void]AddPositiveIntParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue) {
			if (([int]($parameterValue)) -gt 0) {
				$sb.appendformat(" -{0} {1}", $parameterName, $parameterValue)
			}
		}
	}

	[void]AddSwitchParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and $parameterValue) {
			$sb.appendformat(" -{0}", $parameterName)
		}
	}

	[void]AddArrayParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and $parameterValue.count -gt 0) {
			$sb.appendformat(" -{0} {1}", $parameterName, (ConvertTo-PsonStringArray $parameterValue))
		}
	}

	[void]AddHashtableParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue -and $parameterValue.count -gt 0) {
			$sb.appendformat(" -{0} {1}", $parameterName, (ConvertTo-PsonMap $parameterValue))
		}
	}

	[void]AddKeyValueParameter([text.stringbuilder] $sb, [string] $parameterName) {

		$parameterValue = ($this.config | select-object -property $parameterName).$parameterName
		if ($null -ne $parameterValue) {
			$kv = [Tuple`2[string,string]]$parameterValue
			$sb.appendformat(" -{0} ([Tuple``2[string,string]]::new('{1}','{2}'))", $parameterName, $kv.item1.Replace("'","''"), $kv.item2.Replace("'","''"))
		}
	}
}

