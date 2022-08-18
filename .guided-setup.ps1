<#PSScriptInfo
.VERSION 2.3.0
.GUID e917c41a-260f-4ea4-980d-db00f8baef1b
.AUTHOR Code Dx
#>

using module @{ModuleName='guided-setup'; RequiredVersion='1.6.0' }

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

Set-PSDebug -Strict

Write-Host 'Loading...' -NoNewline

'./setup/core/common/prereqs.ps1',
'./setup/steps/step.ps1',
'./setup/steps/welcome.ps1',
'./setup/steps/gitops.ps1',
'./setup/steps/backup.ps1',
'./setup/steps/k8s.ps1',
'./setup/steps/ingress.ps1',
'./setup/steps/image.ps1',
'./setup/steps/orchestration.ps1',
'./setup/steps/authentication.ps1',
'./setup/steps/cpu.ps1',
'./setup/steps/memory.ps1',
'./setup/steps/volume.ps1',
'./setup/steps/ephemeralstorage.ps1',
'./setup/steps/codedx.ps1',
'./setup/steps/cert.ps1',
'./setup/steps/schedule.ps1',
'./setup/steps/database.ps1',
'./setup/steps/summary.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

$config = [ConfigInput]::new()

$graph = New-Object Graph($true)

$s = @{}
[Welcome],
[DeploymentMethod],[HelmManifestWarning],[SealedSecretsNamespace],[SealedSecretsControllerName],[SealedSecretsPublicKeyPath],
[Prerequisites],[PrequisitesNotMet],[WorkDir],[ChooseEnvironment],
[ChooseContext],[SelectContext],[HandleNoContext],
[GetKubernetesPort],
[UseTriageAssistant],
[UseToolOrchestration],[UseExternalDatabase],
[BackupType],[VeleroNamespace],[BackupSchedule],[BackupDatabaseTimeout],[BackupTimeToLive],
[UseDefaultOptions],[UsePodSecurityPolicyOption],[UseNetworkPolicyOption],[UseTlsOption],
[UseLegacyUnknownSigner],[CertsCAPath],[CodeDxSignerName],[ToolOrchestrationSignerName],[LegacyUnknownCertsPath],
[CodeDxNamespace],[CodeDxReleaseName],
[ToolOrchestrationNamespace],[ToolOrchestrationReleaseName],
[ExternalDatabaseHost],[ExternalDatabasePort],[ExternalDatabaseName],[ExternalDatabaseUser], [ExternalDatabasePwd],[ExternalDatabaseOneWayAuth],[ExternalDatabaseCert],
[DatabaseRootPwd],[DatabaseReplicationPwd],[DatabaseUserPwd],[DatabaseReplicaCount],
[CodeDxPassword],[ToolServiceKey],[MinioAdminPassword],[ToolServiceReplicaCount],
[UsePrivateDockerRegistry],[DockerImagePullSecret],[PrivateDockerRegistryHost],[PrivateDockerRegistryUser],[PrivateDockerRegistryPwd],
[UseDefaultDockerImages],[PublicRedirect],
[CodeDxTomcatDockerImage],[CodeDxToolsDockerImage],[CodeDxToolsMonoDockerImage],[CodeDxToolServiceDockerImage],[CodeDxSendResultsDockerImage],[CodeDxSendErrorResultsDockerImage],[CodeDxNewAnalysisDockerImage],[CodeDxPrepareDockerImage],[CodeDxPreDeleteDockerImage],
[CodeDxTomcatInitDockerImage],[CodeDxMariaDBDockerImage],[MinioDockerImage],[CodeDxWorkflowControllerDockerImage],[CodeDxWorkflowExecutorDockerImage],
[IngressKind],[CertManagerIssuerType],[CertManagerIssuer],[IngressCertificateArn],
[NginxTLS],[NginxTLSSecretName],
[DnsName],
[AuthenticationType],[LdapInstructions],[SamlAuthenticationDnsName],[SamlIdpMetadata],[SamlAppName],[SamlKeystorePwd],[SamlPrivateKeyPwd],[SamlExtraConfig],
[DefaultCPU],[CodeDxCPU],[MasterDatabaseCPU],[SubordinateDatabaseCPU],[ToolServiceCPU],[MinIOCPU],[WorkflowCPU],
[DefaultMemory],[CodeDxMemory],[MasterDatabaseMemory],[SubordinateDatabaseMemory],[ToolServiceMemory],[MinIOMemory],[WorkflowMemory],
[DefaultEphemeralStorage],[CodeDxEphemeralStorage],[MasterDatabaseEphemeralStorage],[SubordinateDatabaseEphemeralStorage],[ToolServiceEphemeralStorage],[MinIOEphemeralStorage],[WorkflowEphemeralStorage],
[DefaultVolumeSize],[CodeDxVolumeSize],[MasterDatabaseVolumeSize],[SubordinateDatabaseVolumeSize],[MinIOVolumeSize],[StorageClassName],
[UseDefaultCACerts],[CACertsFile],[CACertsFilePassword],[CACertsChangePassword],[CACertsFileNewPassword],[AddExtraCertificates],[ExtraCertificates],
[UseNodeSelectors],[CodeDxNodeSelector],[MasterDatabaseNodeSelector],[SubordinateDatabaseNodeSelector],[ToolServiceNodeSelector],[MinIONodeSelector],[WorkflowControllerNodeSelector],[ToolNodeSelector],
[UseTolerations],[CodeDxTolerations],[MasterDatabaseTolerations],[SubordinateDatabaseTolerations],[ToolServiceTolerations],[MinIOTolerations],[WorkflowControllerTolerations],[ToolTolerations],
[Finish],[Abort]
| ForEach-Object {
	$s[$_] = new-object -type $_ -args $config
	Add-Step $graph $s[$_]
}

Add-StepTransitions $graph $s[[Welcome]] $s[[DeploymentMethod]]

Add-StepTransitions $graph $s[[DeploymentMethod]] $s[[HelmManifestWarning]],$s[[Prerequisites]],$s[[PrequisitesNotMet]],$s[[Abort]]
Add-StepTransitions $graph $s[[DeploymentMethod]] $s[[Prerequisites]],$s[[WorkDir]],$s[[ChooseEnvironment]],$s[[ChooseContext]]

Add-StepTransitions $graph $s[[ChooseContext]] $s[[HandleNoContext]],$s[[Abort]]
Add-StepTransitions $graph $s[[ChooseContext]] $s[[SelectContext]],$s[[PrequisitesNotMet]],$s[[Abort]]
Add-StepTransitions $graph $s[[ChooseContext]] $s[[SelectContext]],$s[[GetKubernetesPort]]

Add-StepTransitions $graph $s[[GetKubernetesPort]] $s[[SealedSecretsNamespace]],$s[[SealedSecretsControllerName]],$s[[SealedSecretsPublicKeyPath]],$s[[UseTriageAssistant]]
Add-StepTransitions $graph $s[[GetKubernetesPort]] $s[[UseTriageAssistant]],$s[[UseToolOrchestration]],$s[[UseExternalDatabase]],$s[[BackupType]],$s[[VeleroNamespace]],$s[[BackupSchedule]],$s[[BackupDatabaseTimeout]],$s[[BackupTimeToLive]],$s[[UseDefaultOptions]]
Add-StepTransitions $graph $s[[BackupType]] $s[[UseDefaultOptions]]

Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[UsePodSecurityPolicyOption]],$s[[UseNetworkPolicyOption]],$s[[UseTlsOption]]
Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[UseLegacyUnknownSigner]]
Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[CertsCAPath]]
Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[CodeDxNamespace]]

Add-StepTransitions $graph $s[[UseTlsOption]] $s[[UseLegacyUnknownSigner]],$s[[LegacyUnknownCertsPath]],$s[[CodeDxNamespace]]
Add-StepTransitions $graph $s[[UseTlsOption]] $s[[UseLegacyUnknownSigner]],$s[[CertsCAPath]]
Add-StepTransitions $graph $s[[UseTlsOption]] $s[[CertsCAPath]],$s[[CodeDxSignerName]],$s[[ToolOrchestrationSignerName]],$s[[CodeDxNamespace]]
Add-StepTransitions $graph $s[[UseTlsOption]] $s[[CertsCAPath]],$s[[CodeDxSignerName]],$s[[CodeDxNamespace]]
Add-StepTransitions $graph $s[[UseTlsOption]] $s[[CodeDxNamespace]]

Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[ToolOrchestrationNamespace]],$s[[ToolOrchestrationReleaseName]],$s[[ExternalDatabaseHost]]
Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[ToolOrchestrationNamespace]],$s[[ToolOrchestrationReleaseName]],$s[[DatabaseRootPwd]]
Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[ExternalDatabaseHost]]
Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[DatabaseRootPwd]]

Add-StepTransitions $graph $s[[DatabaseRootPwd]] $s[[DatabaseReplicationPwd]],$s[[DatabaseUserPwd]],$s[[DatabaseReplicaCount]],$s[[UseDefaultCACerts]]
Add-StepTransitions $graph $s[[DatabaseReplicaCount]] $s[[CACertsFile]]
Add-StepTransitions $graph $s[[ExternalDatabaseHost]] $s[[ExternalDatabasePort]],$s[[ExternalDatabaseName]],$s[[ExternalDatabaseUser]],$s[[ExternalDatabasePwd]],$s[[ExternalDatabaseOneWayAuth]]

Add-StepTransitions $graph $s[[ExternalDatabaseOneWayAuth]] $s[[ExternalDatabaseCert]],$s[[CACertsFile]]
Add-StepTransitions $graph $s[[ExternalDatabaseOneWayAuth]] $s[[UseDefaultCACerts]]

Add-StepTransitions $graph $s[[UseDefaultCACerts]] $s[[CACertsFile]],$s[[CACertsFilePassword]],$s[[CACertsChangePassword]]
Add-StepTransitions $graph $s[[CACertsChangePassword]] $s[[CACertsFileNewPassword]],$s[[AddExtraCertificates]]
Add-StepTransitions $graph $s[[CACertsChangePassword]] $s[[AddExtraCertificates]]
Add-StepTransitions $graph $s[[UseDefaultCACerts]] $s[[CodeDxPassword]]

Add-StepTransitions $graph $s[[AddExtraCertificates]] $s[[ExtraCertificates]],$s[[CodeDxPassword]]
Add-StepTransitions $graph $s[[AddExtraCertificates]] $s[[CodeDxPassword]]

Add-StepTransitions $graph $s[[CodeDxPassword]] $s[[ToolServiceKey]],$s[[MinioAdminPassword]],$s[[ToolServiceReplicaCount]],$s[[UsePrivateDockerRegistry]]
Add-StepTransitions $graph $s[[CodeDxPassword]] $s[[UsePrivateDockerRegistry]]

Add-StepTransitions $graph $s[[UsePrivateDockerRegistry]] $s[[DockerImagePullSecret]],$s[[PrivateDockerRegistryHost]],$s[[PrivateDockerRegistryUser]],$s[[PrivateDockerRegistryPwd]],$s[[UseDefaultDockerImages]]

Add-StepTransitions $graph $s[[UsePrivateDockerRegistry]] $s[[UseDefaultDockerImages]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[PublicRedirect]],$s[[IngressKind]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[CodeDxTomcatDockerImage]],$s[[CodeDxTomcatInitDockerImage]],$s[[CodeDxMariaDBDockerImage]],$s[[CodeDxToolsDockerImage]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[CodeDxTomcatDockerImage]],$s[[CodeDxTomcatInitDockerImage]],$s[[CodeDxMariaDBDockerImage]],$s[[IngressKind]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[CodeDxTomcatDockerImage]],$s[[CodeDxTomcatInitDockerImage]],$s[[CodeDxToolsDockerImage]]
Add-StepTransitions $graph $s[[CodeDxToolsDockerImage]] $s[[CodeDxToolsMonoDockerImage]],$s[[CodeDxToolServiceDockerImage]],$s[[CodeDxSendResultsDockerImage]],$s[[CodeDxSendErrorResultsDockerImage]],$s[[CodeDxNewAnalysisDockerImage]],$s[[CodeDxPrepareDockerImage]],$s[[CodeDxPreDeleteDockerImage]],$s[[MinioDockerImage]],$s[[CodeDxWorkflowControllerDockerImage]],$s[[CodeDxWorkflowExecutorDockerImage]],$s[[IngressKind]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[CodeDxTomcatDockerImage]],$s[[CodeDxTomcatInitDockerImage]],$s[[IngressKind]]

Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[IngressKind]]

Add-StepTransitions $graph $s[[IngressKind]] $s[[NginxTLS]],$s[[CertManagerIssuerType]],$s[[CertManagerIssuer]],$s[[DnsName]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[NginxTLS]],$s[[NginxTLSSecretName]],$s[[DnsName]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[NginxTLS]],$s[[DnsName]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[IngressCertificateArn]],$s[[AuthenticationType]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[DnsName]],$s[[AuthenticationType]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[AuthenticationType]]

Add-StepTransitions $graph $s[[AuthenticationType]] $s[[LdapInstructions]],$s[[DefaultCPU]]
Add-StepTransitions $graph $s[[AuthenticationType]] $s[[SamlAuthenticationDnsName]],$s[[SamlIdpMetadata]],$s[[SamlAppName]],$s[[SamlKeystorePwd]],$s[[SamlPrivateKeyPwd]],$s[[SamlExtraConfig]],$s[[DefaultCPU]]
Add-StepTransitions $graph $s[[AuthenticationType]] $s[[SamlIdpMetadata]]
Add-StepTransitions $graph $s[[AuthenticationType]] $s[[DefaultCPU]]

Add-StepTransitions $graph $s[[DefaultCPU]] $s[[CodeDxCPU]]
Add-StepTransitions $graph $s[[DefaultCPU]] $s[[DefaultMemory]]

Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[MasterDatabaseCPU]],$s[[SubordinateDatabaseCPU]],$s[[ToolServiceCPU]],$s[[MinIOCPU]],$s[[WorkflowCPU]],$s[[DefaultMemory]]
Add-StepTransitions $graph $s[[MasterDatabaseCPU]] $s[[ToolServiceCPU]]
Add-StepTransitions $graph $s[[MasterDatabaseCPU]] $s[[DefaultMemory]]
Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[ToolServiceCPU]],$s[[MinIOCPU]],$s[[WorkflowCPU]],$s[[DefaultMemory]]
Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[MasterDatabaseCPU]],$s[[SubordinateDatabaseCPU]],$s[[DefaultMemory]]
Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[DefaultMemory]]

Add-StepTransitions $graph $s[[DefaultMemory]] $s[[CodeDxMemory]]
Add-StepTransitions $graph $s[[DefaultMemory]] $s[[DefaultEphemeralStorage]]

Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[MasterDatabaseMemory]],$s[[SubordinateDatabaseMemory]],$s[[ToolServiceMemory]],$s[[MinIOMemory]],$s[[WorkflowMemory]],$s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[MasterDatabaseMemory]] $s[[ToolServiceMemory]]
Add-StepTransitions $graph $s[[MasterDatabaseMemory]] $s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[ToolServiceMemory]],$s[[MinIOMemory]],$s[[WorkflowMemory]],$s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[MasterDatabaseMemory]],$s[[SubordinateDatabaseMemory]],$s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[DefaultEphemeralStorage]]

Add-StepTransitions $graph $s[[DefaultEphemeralStorage]] $s[[CodeDxEphemeralStorage]]
Add-StepTransitions $graph $s[[DefaultEphemeralStorage]] $s[[DefaultVolumeSize]]

Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[MasterDatabaseEphemeralStorage]],$s[[SubordinateDatabaseEphemeralStorage]],$s[[ToolServiceEphemeralStorage]],$s[[MinIOEphemeralStorage]],$s[[WorkflowEphemeralStorage]],$s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[MasterDatabaseEphemeralStorage]] $s[[ToolServiceEphemeralStorage]]
Add-StepTransitions $graph $s[[MasterDatabaseEphemeralStorage]] $s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[ToolServiceEphemeralStorage]],$s[[MinIOEphemeralStorage]],$s[[WorkflowEphemeralStorage]],$s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[MasterDatabaseEphemeralStorage]],$s[[SubordinateDatabaseEphemeralStorage]],$s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[DefaultVolumeSize]]

Add-StepTransitions $graph $s[[DefaultVolumeSize]] $s[[CodeDxVolumeSize]]
Add-StepTransitions $graph $s[[DefaultVolumeSize]] $s[[StorageClassName]]

Add-StepTransitions $graph $s[[CodeDxVolumeSize]] $s[[MasterDatabaseVolumeSize]],$s[[SubordinateDatabaseVolumeSize]],$s[[MinIOVolumeSize]],$s[[StorageClassName]]
Add-StepTransitions $graph $s[[MasterDatabaseVolumeSize]] $s[[MinIOVolumeSize]]
Add-StepTransitions $graph $s[[MasterDatabaseVolumeSize]] $s[[StorageClassName]]
Add-StepTransitions $graph $s[[SubordinateDatabaseVolumeSize]] $s[[StorageClassName]]
Add-StepTransitions $graph $s[[CodeDxVolumeSize]] $s[[MinIOVolumeSize]],$s[[StorageClassName]]
Add-StepTransitions $graph $s[[CodeDxVolumeSize]] $s[[StorageClassName]]

Add-StepTransitions $graph $s[[StorageClassName]] $s[[UseNodeSelectors]]
Add-StepTransitions $graph $s[[StorageClassName]] $s[[Finish]]

Add-StepTransitions $graph $s[[UseNodeSelectors]] $s[[CodeDxNodeSelector]],$s[[MasterDatabaseNodeSelector]],$s[[SubordinateDatabaseNodeSelector]],$s[[ToolServiceNodeSelector]]
Add-StepTransitions $graph $s[[UseNodeSelectors]] $s[[CodeDxNodeSelector]],$s[[ToolServiceNodeSelector]],$s[[MinIONodeSelector]],$s[[WorkflowControllerNodeSelector]],$s[[ToolNodeSelector]],$s[[UseTolerations]]
Add-StepTransitions $graph $s[[UseNodeSelectors]] $s[[CodeDxNodeSelector]],$s[[UseTolerations]]
Add-StepTransitions $graph $s[[UseNodeSelectors]] $s[[UseTolerations]]
Add-StepTransitions $graph $s[[SubordinateDatabaseNodeSelector]] $s[[UseTolerations]]
Add-StepTransitions $graph $s[[MasterDatabaseNodeSelector]] $s[[ToolServiceNodeSelector]]
Add-StepTransitions $graph $s[[MasterDatabaseNodeSelector]] $s[[UseTolerations]]

Add-StepTransitions $graph $s[[UseTolerations]] $s[[CodeDxTolerations]],$s[[MasterDatabaseTolerations]],$s[[SubordinateDatabaseTolerations]],$s[[ToolServiceTolerations]]
Add-StepTransitions $graph $s[[UseTolerations]] $s[[CodeDxTolerations]],$s[[ToolServiceTolerations]],$s[[MinIOTolerations]],$s[[WorkflowControllerTolerations]],$s[[ToolTolerations]],$s[[Finish]]
Add-StepTransitions $graph $s[[UseTolerations]] $s[[CodeDxTolerations]],$s[[Finish]]
Add-StepTransitions $graph $s[[UseTolerations]] $s[[Finish]]
Add-StepTransitions $graph $s[[SubordinateDatabaseTolerations]] $s[[Finish]]
Add-StepTransitions $graph $s[[MasterDatabaseTolerations]] $s[[ToolServiceTolerations]]
Add-StepTransitions $graph $s[[MasterDatabaseTolerations]] $s[[Finish]]


if ($DebugPreference -eq 'Continue') {
	# Print graph at https://dreampuf.github.io/GraphvizOnline (select 'dot' Engine and use Format 'png-image-element')
	write-host 'digraph G {'
	$s.keys | ForEach-Object { $node = $s[$_]; ($node.getNeighbors() | ForEach-Object { write-host ('{0} -> {1};' -f $node.name,$_) }) }
	write-host '}'
}

try {
	$vStack = Invoke-GuidedSetup 'Code Dx - Guided Setup' $s[[Welcome]] ($s[[Finish]],$s[[Abort]])

	Write-StepGraph (join-path ($config.workDir ?? './') 'graph.path') $s $vStack
} catch {
	Write-Host "`n`nAn unexpected error occurred: $_`n"
}
