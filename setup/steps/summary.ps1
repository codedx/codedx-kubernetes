
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

	static [string] hidden $description = @'
You have now specified what's necessary to run the core setup script.

At this point, you can launch the script to install Code Dx 
components based on the configuration data you entered. Alternatively, you 
can save the script command line to a file to run it at a later time.
	
If you want to save the script command line, you can exclude passwords/keys 
by generating a prerequisites script that you must run before running the 
setup script. The prerequisites script will create Kubernetes secrets with 
passwords/keys that the setup script expects to find at run-time.
	
Note: If you need to add setup.ps1 parameters such as custom codedx.props 
settings, save the setup script command to a file and include any extra 
parameters. Refer to the following URL for details on setup.ps1 parameters: 
https://github.com/codedx/codedx-kubernetes/tree/master/setup/core
'@
		
	static [string] hidden $k8sSecretScript = @'
function Set-KubectlContext([string] $contextName) {

	kubectl config use-context $contextName
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to change kubectl context, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-Namespace([string] $namespace) {

	if ('' -eq $namespace) {
		return $false
	}
	
	kubectl get namespace $namespace | out-null
	0 -eq $LASTEXITCODE
}

function New-Namespace([string] $namespace) {

	if (Test-Namespace $namespace) {
		return
	}

	kubectl create namespace $namespace
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create namespace $namespace, kubectl exited with code $LASTEXITCODE."
	}
}

function Test-Secret([string] $namespace, [string] $name) {

	kubectl -n $namespace get secret $name | out-null
	0 -eq $LASTEXITCODE
}

function Remove-Secret([string] $namespace, [string] $name) {

	kubectl -n $namespace delete secret $name | out-null
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to delete secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}

function New-GenericSecret([string] $namespace, [string] $name, [hashtable] $keyValues) {
	
	if (Test-Secret $namespace $name) {
		Remove-Secret $namespace $name
	}

	$pairs = @()
	$keyValues.Keys | ForEach-Object {

		# apply escape required when running from pwsh
		$value = $keyValues[$_]
		$value = $value -replace '"','\"'

		$pairs += "--from-literal=$_=$value"
	}

	kubectl -n $namespace create secret generic $name $pairs
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to create secret named $name, kubectl exited with code $LASTEXITCODE."
	}
}
'@

	Finish([ConfigInput] $config) : base(
		[Finish].Name, 
		$config,
		'Next Step',
		[Finish]::description,
		'What would you like to do next?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$options = @([tuple]::create('&Run now', 'Run the setup script without saving the script command a file'))

		if ($this.config.UseGitOps()) {
			$options += [tuple]::create('Save &GitOps command', 'Save a command to generate GitOps outputs')
		} else {
			$options += [tuple]::create('&Save command', 'Save the setup script using password/key script parameters')
			$options += [tuple]::create('Save command with &Kubernetes secret(s)', 'Save the setup script using k8s secret(s) for password/key script parameters')
		}

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
		$usePd = -not $useGitOps -and ([MultipleChoiceQuestion]$question).choice -eq 2

		if ($useGitOps) {
			'useHelmOperator','useHelmController','useHelmManifest','skipSealedSecrets' | ForEach-Object {
				$this.AddSwitchParameter($sb, $_)
			}
			'sealedSecretsNamespace','sealedSecretsControllerName','sealedSecretsPublicKeyPath' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		}

		if (-not $usePd) {
			'dockerRegistryPwd','codedxAdminPwd','caCertsFilePwd','caCertsFileNewPwd','codedxDatabaseUserPwd' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
		}

		'skipTLS','skipServiceTLS','skipPSPs','skipNetworkPolicies','skipIngressEnabled','useSaml','createSCCs','skipUseRootDatabaseUser' | ForEach-Object {
			$this.AddSwitchParameter($sb, $_)
		}

		if ($this.config.useSaml) {
			'samlIdentityProviderMetadataPath','samlAppName' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}

			if (-not $usePd) {
				'samlKeystorePwd','samlPrivateKeyPwd' | ForEach-Object {
					$this.AddParameter($sb, $_)
				}
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

			if (-not $usePd) {
				'mariadbRootPwd','mariadbReplicatorPwd' | ForEach-Object {
					$this.AddParameter($sb, $_)
				}
			}
		} else {
			
			'externalDatabaseHost','externalDatabaseName' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}

			if (-not $usePd) {
				'externalDatabaseUser','externalDatabasePwd' | ForEach-Object {
					$this.AddParameter($sb, $_)
				}
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
			'namespaceToolOrchestration','releaseNameToolOrchestration' | ForEach-Object {
				$this.AddParameter($sb, $_)
			}
			'toolServiceNodeSelector','toolServiceNoScheduleExecuteToleration',
			'minioNodeSelector','minioNoScheduleExecuteToleration',
			'workflowControllerNodeSelector','workflowControllerNoScheduleExecuteToleration',
			'toolNodeSelector','toolNoScheduleExecuteToleration' | ForEach-Object {
				$this.AddKeyValueParameter($sb, $_)
			}

			if (-not $usePd) {
				'toolServiceApiKey','minioAdminPwd' | ForEach-Object {
					$this.AddParameter($sb, $_)
				}
			}
		} else {
			$this.AddSwitchParameter($sb, 'skipToolOrchestration')
		}

		$this.AddArrayParameter($sb, 'extraCodeDxTrustedCaCertPaths')

		'ingressAnnotationsCodeDx','serviceAnnotationsCodeDx' | ForEach-Object {
			$this.AddHashtableParameter($sb, $_)
		}

		$setupCmdLine = $sb.ToString()
		$setupPdCmdLine = ''
		if ($usePd) {
			$setupPdCmdLine = $this.BuildPrereqScript()
		}

		$this.PrintNotes()
		if ($runNow) {
			if (-not ($this.RunNow($setupPdCmdLine, $setupCmdLine))) {
				Write-Host 'The setup script failed to run successfully.'
			}
		}

		$this.SaveScripts($setupPdCmdLine, $setupCmdLine, (-not $runNow))
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

	[bool]RunNow([string] $setupPdCmdLine, [string] $setupCmdLine) {

		Write-Host 'Starting deployment...'
		if ($setupPdCmdLine -ne '') {

			Write-Host 'Creating k8s secret(s)...'
			$cmd = ([convert]::ToBase64String([text.encoding]::unicode.getbytes($setupPdCmdLine)))
			$process = Start-Process pwsh '-e',$cmd -Wait -PassThru
			if ($process.ExitCode -ne 0) {
				return $false
			}
		}

		Write-Host 'Running setup command...'
		$cmd = ([convert]::ToBase64String([text.encoding]::unicode.getbytes($setupCmdLine)))
		$process = Start-Process pwsh '-e',$cmd -Wait -PassThru
		if ($process.ExitCode -ne 0) {
			return $false
		}
		return $true
	}

	[void]SaveScripts([string] $setupPdCmdLine, [string] $setupCmdLine, [bool] $showRunInstruction) {

		Write-Host "Writing setup script(s) to $($this.config.workDir)..."
		if ($setupPdCmdLine -ne '') {
			
			$prereqsScriptPath = join-path $this.config.workDir 'run-prereqs.ps1'
			Write-Host "  Writing $prereqsScriptPath..."
			$setupPdCmdLine | Out-File $prereqsScriptPath

			if ($showRunInstruction) {
				Write-Host "  Run: pwsh ""$prereqsScriptPath"""
			}
		}

		$setupScriptPath = join-path $this.config.workDir 'run-setup.ps1'
		Write-Host "  Writing $setupScriptPath..."
		$setupCmdLine | Out-File $setupScriptPath

		if ($showRunInstruction) {
			Write-Host "  Run: pwsh ""$setupScriptPath"""
		}
	}

	[hashtable] GetCodeDxPdTable() {

		$pd = @{}

		$pd['admin-password'] = $this.config.codedxAdminPwd
		if ($this.config.caCertsFilePwd -ne '') {
			$pd['cacerts-password'] = $this.config.caCertsFilePwd
		}
		if ($this.config.caCertsFileNewPwd -ne '') {
			$pd['cacerts-new-password'] = $this.config.caCertsFileNewPwd
		}
		if (-not $this.config.skipPrivateDockerRegistry) {
			$pd['docker-registry-password'] = $this.config.dockerRegistryPwd
		}

		if ($this.config.skipDatabase) {
			$pd['mariadb-codedx-username'] = $this.config.externalDatabaseUser
			$pd['mariadb-codedx-password'] = $this.config.externalDatabasePwd
		}

		if ($this.config.useSaml) {
			$pd['saml-keystore-password'] = $this.config.samlKeystorePwd
			$pd['saml-private-key-password'] = $this.config.samlPrivateKeyPwd
		}
		return $pd
	}

	[hashtable] GetDatabasePdTable() {

		$pd = @{}
		if (-not $this.config.skipDatabase) {
			$pd['mariadb-root-password'] = $this.config.mariadbRootPwd
			$pd['mariadb-replication-password'] = $this.config.mariadbReplicatorPwd

			if ($this.config.skipUseRootDatabaseUser) {
				$pd['mariadb-password'] = $this.config.codedxDatabaseUserPwd
			}
		}
		return $pd
	}

	[hashtable] GetToolOrchestrationPdTable() {

		$pd = @{}
		if (-not $this.config.skipToolOrchestration) {
			$pd['api-key'] = $this.config.toolServiceApiKey
		}
		return $pd
	}

	[hashtable] GetToolOrchestrationStoragePdTable() {

		$pd = @{}
		if (-not $this.config.skipToolOrchestration) {
			$pd['secret-key'] = $this.config.minioAdminPwd
		}
		return $pd
	}

	[string]BuildPrereqScript() {

		$pdSb = new-object text.stringbuilder([Finish]::k8sSecretScript)

		$pdSb.AppendFormat("`nSet-KubectlContext '{0}'`n", $this.config.kubeContextName.Replace("'", "''"))
		
		$pdSb.AppendFormat("`nNew-Namespace '{0}'`n", $this.config.namespaceCodeDx)
		if (-not $this.config.skipToolOrchestration) {
			$pdSb.AppendFormat("`nNew-Namespace '{0}'`n", $this.config.namespaceToolOrchestration)
		}

		$template = "`nNew-GenericSecret '{0}' '{1}' {2}`n"
		$pdSb.AppendFormat($template, $this.config.namespaceCodeDx, (Get-CodeDxPdSecretName $this.config.releaseNameCodeDx), (ConvertTo-PsonMap $this.GetCodeDxPdTable()))

		$pdDatabase = $this.GetDatabasePdTable()
		if ($pdDatabase.Count -gt 0) {
			$pdSb.AppendFormat($template, $this.config.namespaceCodeDx, (Get-DatabasePdSecretName $this.config.releaseNameCodeDx), (ConvertTo-PsonMap $pdDatabase))
		}

		$pdToolOrchestration = $this.GetToolOrchestrationPdTable()
		if ($pdToolOrchestration.Count -gt 0) {
			$pdSb.AppendFormat($template, $this.config.namespaceToolOrchestration, (Get-ToolServicePdSecretName $this.config.releaseNameToolOrchestration), (ConvertTo-PsonMap $pdToolOrchestration))
		}

		$pdToolOrchestrationStorage = $this.GetToolOrchestrationStoragePdTable()
		if ($pdToolOrchestrationStorage.Count -gt 0) {
			$pdSb.AppendFormat($template, $this.config.namespaceToolOrchestration, (Get-MinioPdSecretName $this.config.releaseNameToolOrchestration), (ConvertTo-PsonMap $pdToolOrchestrationStorage))
		}

		return $pdSb.toString()
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

