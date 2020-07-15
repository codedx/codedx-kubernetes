<#PSScriptInfo
.VERSION 1.0.0
.GUID e917c41a-260f-4ea4-980d-db00f8baef1b
.AUTHOR Code Dx
#>

$ErrorActionPreference = 'Stop'
$VerbosePreference = 'Continue'

$DebugPreference='SilentlyContinue'

Set-PSDebug -Strict

Write-Host 'Loading...' -NoNewline

'./setup/powershell-algorithms/data-structures.ps1',
'./setup/core/common/question.ps1',
'./setup/steps/step.ps1',
'./setup/steps/welcome.ps1',
'./setup/steps/k8s.ps1',
'./setup/steps/ingress.ps1',
'./setup/steps/image.ps1',
'./setup/steps/orchestration.ps1',
'./setup/steps/cpu.ps1',
'./setup/steps/memory.ps1',
'./setup/steps/volume.ps1',
'./setup/steps/ephemeralstorage.ps1',
'./setup/steps/codedx.ps1',
'./setup/steps/database.ps1',
'./setup/steps/summary.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

function Add-Step([Graph] $graph, [Step] $step) {

	$graph.addVertex($step) | out-null
}

function Add-StepTransition([Graph] $graph, [Step] $from, [Step] $to) {

	Write-Debug "Adding step transition from $($from.name) to $($to.name)..."
	foreach ($neighbor in $from.getNeighbors()) {
		if ($neighbor.name -eq $to.name) {
			return
		}
	}
	$graph.addEdge([GraphEdge]::new($from, $to)) | out-null
}

function Add-StepTransitions([Graph] $graph, [Step] $from, [Step[]] $toSteps) {

	for ($i = 0; $i -lt $toSteps.count; $i++) {
		$from = $i -eq 0 ? $from : $toSteps[$i-1]
		$to = $toSteps[$i]
		Add-StepTransition $graph $from $to
	}
}

function Clear-HostStep() {
	if ($DebugPreference -ne 'Continue') {
		Clear-Host
		$Host.UI.RawUI.CursorPosition = New-Object System.Management.Automation.Host.Coordinates 0,5
	}
}

$config = [ConfigInput]::new()

$graph = New-Object Graph($true)

$s = @{}
[Welcome],[Prerequisites],[PrequisitesNotMet],[WorkDir],[ChooseEnvironment],
[ChooseContext],[SelectContext],[HandleNoContext],
[GetKubernetesPort],
[UseToolOrchestration],[UseExternalDatabase],
[UseDefaultOptions],[UsePodSecurityPolicyOption],[UseNetworkPolicyOption],[UseTlsOption],[CertsCAPath],
[CodeDxNamespace],[CodeDxReleaseName],
[ToolOrchestrationNamespace],[ToolOrchestrationReleaseName],
[ExternalDatabaseHost],[ExternalDatabasePort],[ExternalDatabaseName],[ExternalDatabaseUser], [ExternalDatabasePwd],[ExternalDatabaseOneWayAuth],[ExternalDatabaseCert],
[DatabaseRootPwd],[DatabaseReplicationPwd],[DatabaseReplicaCount],
[CodeDxPassword],[ToolServiceKey],[MinioAdminPassword],[ToolServiceReplicaCount],
[UsePrivateDockerRegistry],[DockerImagePullSecret],[PrivateDockerRegistryHost],[PrivateDockerRegistryUser],[PrivateDockerRegistryPwd],
[UseDefaultDockerImages],[CodeDxTomcatDockerImage],[CodeDxToolsDockerImage],[CodeDxToolsMonoDockerImage],[CodeDxToolServiceDockerImage],[CodeDxSendResultsDockerImage],[CodeDxSendErrorResultsDockerImage],[CodeDxNewAnalysisDockerImage],[CodeDxPreDeleteDockerImage],
[IngressKind],[NginxIngressNamespace],[NginxIngressAddress],
[LetsEncryptNamespace],[LetsEncryptClusterIssuer],[LetsEncryptEmail],[IngressCertificateArn],
[DnsName],
[DefaultCPU],[NginxCPU],[CodeDxCPU],[MasterDatabaseCPU],[SubordinateDatabaseCPU],[ToolServiceCPU],[MinIOCPU],[WorkflowCPU],
[DefaultMemory],[NginxMemory],[CodeDxMemory],[MasterDatabaseMemory],[SubordinateDatabaseMemory],[ToolServiceMemory],[MinIOMemory],[WorkflowMemory],
[DefaultEphemeralStorage],[NginxEphemeralStorage],[CodeDxEphemeralStorage],[MasterDatabaseEphemeralStorage],[SubordinateDatabaseEphemeralStorage],[ToolServiceEphemeralStorage],[MinIOEphemeralStorage],[WorkflowEphemeralStorage],
[DefaultVolumeSize],[CodeDxVolumeSize],[MasterDatabaseVolumeSize],[SubordinateDatabaseVolumeSize],[MinIOVolumeSize],[StorageClassName],
[Finish],[Abort]
| ForEach-Object {
	$s[$_] = new-object -type $_ -args $config
	Add-Step $graph $s[$_]
}

Add-StepTransitions $graph $s[[Welcome]] $s[[Prerequisites]],$s[[PrequisitesNotMet]],$s[[Abort]]
Add-StepTransitions $graph $s[[Welcome]] $s[[Prerequisites]],$s[[WorkDir]],$s[[ChooseEnvironment]],$s[[ChooseContext]]

Add-StepTransitions $graph $s[[ChooseContext]] $s[[HandleNoContext]],$s[[Abort]]
Add-StepTransitions $graph $s[[ChooseContext]] $s[[SelectContext]],$s[[GetKubernetesPort]],$s[[UseToolOrchestration]],$s[[UseExternalDatabase]],$s[[UseDefaultOptions]]

Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[UsePodSecurityPolicyOption]],$s[[UseNetworkPolicyOption]],$s[[UseTlsOption]],$s[[CertsCaPath]],$s[[CodeDxNamespace]]
Add-StepTransitions $graph $s[[UseTlsOption]] $s[[CodeDxNamespace]]
Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[CertsCaPath]],$s[[CodeDxNamespace]]
Add-StepTransitions $graph $s[[UseDefaultOptions]] $s[[CodeDxNamespace]]

Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[ToolOrchestrationNamespace]],$s[[ToolOrchestrationReleaseName]],$s[[ExternalDatabaseHost]]
Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[ToolOrchestrationNamespace]],$s[[ToolOrchestrationReleaseName]],$s[[DatabaseRootPwd]]
Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[ExternalDatabaseHost]]
Add-StepTransitions $graph $s[[CodeDxNamespace]] $s[[CodeDxReleaseName]],$s[[DatabaseRootPwd]]

Add-StepTransitions $graph $s[[DatabaseRootPwd]] $s[[DatabaseReplicationPwd]],$s[[DatabaseReplicaCount]],$s[[CodeDxPassword]]
Add-StepTransitions $graph $s[[ExternalDatabaseHost]] $s[[ExternalDatabasePort]],$s[[ExternalDatabaseName]],$s[[ExternalDatabaseUser]],$s[[ExternalDatabasePwd]],$s[[ExternalDatabaseOneWayAuth]],$s[[ExternalDatabaseCert]],$s[[CodeDxPassword]]
Add-StepTransitions $graph $s[[ExternalDatabaseOneWayAuth]] $s[[CodeDxPassword]]

Add-StepTransitions $graph $s[[CodeDxPassword]] $s[[ToolServiceKey]],$s[[MinioAdminPassword]],$s[[ToolServiceReplicaCount]],$s[[UsePrivateDockerRegistry]]
Add-StepTransitions $graph $s[[CodeDxPassword]] $s[[UsePrivateDockerRegistry]]

Add-StepTransitions $graph $s[[UsePrivateDockerRegistry]] $s[[DockerImagePullSecret]],$s[[PrivateDockerRegistryHost]],$s[[PrivateDockerRegistryUser]],$s[[PrivateDockerRegistryPwd]],$s[[UseDefaultDockerImages]]

Add-StepTransitions $graph $s[[UsePrivateDockerRegistry]] $s[[UseDefaultDockerImages]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[CodeDxTomcatDockerImage]],$s[[CodeDxToolsDockerImage]],$s[[CodeDxToolsMonoDockerImage]],$s[[CodeDxToolServiceDockerImage]],$s[[CodeDxSendResultsDockerImage]],$s[[CodeDxSendErrorResultsDockerImage]],$s[[CodeDxNewAnalysisDockerImage]],$s[[CodeDxPreDeleteDockerImage]],$s[[IngressKind]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[CodeDxTomcatDockerImage]],$s[[IngressKind]]
Add-StepTransitions $graph $s[[UseDefaultDockerImages]] $s[[IngressKind]]

Add-StepTransitions $graph $s[[IngressKind]] $s[[NginxIngressNamespace]],$s[[NginxIngressAddress]],$s[[LetsEncryptNamespace]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[NginxIngressNamespace]],$s[[LetsEncryptNamespace]],$s[[LetsEncryptClusterIssuer]],$s[[LetsEncryptEmail]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[IngressCertificateArn]]
Add-StepTransitions $graph $s[[IngressKind]] $s[[DefaultCPU]]

Add-StepTransitions $graph $s[[LetsEncryptEmail]] $s[[DnsName]],$s[[DefaultCPU]]
Add-StepTransitions $graph $s[[IngressCertificateArn]] $s[[DefaultCPU]]

Add-StepTransitions $graph $s[[DefaultCPU]] $s[[NginxCPU]],$s[[CodeDxCPU]]
Add-StepTransitions $graph $s[[DefaultCPU]] $s[[CodeDxCPU]]
Add-StepTransitions $graph $s[[DefaultCPU]] $s[[DefaultMemory]]

Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[MasterDatabaseCPU]],$s[[SubordinateDatabaseCPU]],$s[[ToolServiceCPU]],$s[[MinIOCPU]],$s[[WorkflowCPU]],$s[[DefaultMemory]]
Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[ToolServiceCPU]],$s[[MinIOCPU]],$s[[WorkflowCPU]],$s[[DefaultMemory]]
Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[MasterDatabaseCPU]],$s[[SubordinateDatabaseCPU]],$s[[DefaultMemory]]
Add-StepTransitions $graph $s[[CodeDxCPU]] $s[[DefaultMemory]]

Add-StepTransitions $graph $s[[DefaultMemory]] $s[[NginxMemory]],$s[[CodeDxMemory]]
Add-StepTransitions $graph $s[[DefaultMemory]] $s[[CodeDxMemory]]
Add-StepTransitions $graph $s[[DefaultMemory]] $s[[DefaultEphemeralStorage]]

Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[MasterDatabaseMemory]],$s[[SubordinateDatabaseMemory]],$s[[ToolServiceMemory]],$s[[MinIOMemory]],$s[[WorkflowMemory]],$s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[ToolServiceMemory]],$s[[MinIOMemory]],$s[[WorkflowMemory]],$s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[MasterDatabaseMemory]],$s[[SubordinateDatabaseMemory]],$s[[DefaultEphemeralStorage]]
Add-StepTransitions $graph $s[[CodeDxMemory]] $s[[DefaultEphemeralStorage]]

Add-StepTransitions $graph $s[[DefaultEphemeralStorage]] $s[[NginxEphemeralStorage]],$s[[CodeDxEphemeralStorage]]
Add-StepTransitions $graph $s[[DefaultEphemeralStorage]] $s[[CodeDxEphemeralStorage]]
Add-StepTransitions $graph $s[[DefaultEphemeralStorage]] $s[[DefaultVolumeSize]]

Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[MasterDatabaseEphemeralStorage]],$s[[SubordinateDatabaseEphemeralStorage]],$s[[ToolServiceEphemeralStorage]],$s[[MinIOEphemeralStorage]],$s[[WorkflowEphemeralStorage]],$s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[ToolServiceEphemeralStorage]],$s[[MinIOEphemeralStorage]],$s[[WorkflowEphemeralStorage]],$s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[MasterDatabaseEphemeralStorage]],$s[[SubordinateDatabaseEphemeralStorage]],$s[[DefaultVolumeSize]]
Add-StepTransitions $graph $s[[CodeDxEphemeralStorage]] $s[[DefaultVolumeSize]]

Add-StepTransitions $graph $s[[DefaultVolumeSize]] $s[[CodeDxVolumeSize]]
Add-StepTransitions $graph $s[[DefaultVolumeSize]] $s[[StorageClassName]]

Add-StepTransitions $graph $s[[CodeDxVolumeSize]] $s[[MasterDatabaseVolumeSize]],$s[[SubordinateDatabaseVolumeSize]],$s[[MinIOVolumeSize]],$s[[StorageClassName]]
Add-StepTransitions $graph $s[[SubordinateDatabaseVolumeSize]] $s[[StorageClassName]]
Add-StepTransitions $graph $s[[CodeDxVolumeSize]] $s[[MinIOVolumeSize]],$s[[StorageClassName]]
Add-StepTransitions $graph $s[[CodeDxVolumeSize]] $s[[StorageClassName]]

Add-StepTransitions $graph $s[[StorageClassName]] $s[[Finish]]

if ($DebugPreference -eq 'Continue') {
	# Print graph at https://dreampuf.github.io/GraphvizOnline (select 'dot' Engine and use Format 'png-image-element')
	write-host 'digraph G {'
	$s.keys | ForEach-Object { $node = $s[$_]; ($node.getNeighbors() | ForEach-Object { write-host ('{0} -> {1};' -f $node.name,$_) }) }
	write-host '}'
}

$Host.UI.RawUI.WindowTitle = 'Code Dx - Guided Setup'

$v = $s[[Welcome]]
$vStack = new-object collections.stack

try {
	$edgeInfo = @()
	while ($v -ne $s[[Finish]] -and $v -ne $s[[Abort]]) {

		Clear-HostStep
		Write-Debug "`Previous Edges`: $edgeInfo; Running: $($v.Name)..."
		$edgeInfo = @()

		if (-not $v.Run()) {
			$v.Reset()
			if ($vStack.Count -ne 0) {
				$v = $vStack.Pop()
				$v.Reset()
			}
			continue
		}

		$edges = $v.getEdges()
		if ($null -eq $edges) {
			throw "Unexpectedly found 0 edges associated with step $($v.Name)"
		}

		$edges | ForEach-Object {
			$edgeInfo += " $($_.endVertex) ($($_.endVertex.CanRun()))"
		}

		$next = $edges | Where-Object { $_.endVertex.CanRun() } | Select-Object -First 1 -ExpandProperty 'endVertex'
		if ($null -eq $next) {
			Write-Error "Found 0 next steps from $v, options included $($v.getNeighbors())."
		}

		$vStack.Push($v)
		$v = $next
	}

	Clear-HostStep
	$v.Run() | Out-Null
} finally {

	$vStack.Push($v)
	Write-StepGraph (join-path $config.workDir 'graph.path') $s $vStack
}

