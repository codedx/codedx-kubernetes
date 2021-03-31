<#PSScriptInfo
.VERSION 1.2.0
.GUID 9b147f81-cb5d-4f13-830c-f0eb653520a7
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script contains helpers for Code Dx adminstration-related tasks.
#>


param(
	[string] $kubeContext = '',
	[string] $codedxNamespace = 'cdx-app',
	[string] $codedxReleaseName = 'codedx',
	[string] $codedxBaseUrl = '',
	[bool]   $codedxSkipCertificateCheck = $false,
	[string] $codedxAdminApiKey = '',
	[string] $toolOrchestrationNamespace = 'cdx-svc',
	[string] $toolOrchestrationReleaseName = 'codedx-tool-orchestration'
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

'../setup/core/common/codedx.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

function Write-Choices($decisionList) {
	Write-Host "`n---"
	Write-Host "What do you want to do?"

	$lastId = $null
	$decisionList | ForEach-Object {

		$id = $_.id
		if ($lastId -ne $id[0]) {
			Write-Host
		}

		Write-Host "  $($id):" $_.name
		$lastId = $id[0]
	}
	Write-Host "---`n"
}

function Get-Confirmation([string] $confirmation) {
	(Read-Host -prompt "Are you sure? Enter '$confirmation' to proceed") -eq $confirmation
}

function Test-AppCommandPath([string] $commandName) {

	$command = Get-Command $commandName -Type Application -ErrorAction SilentlyContinue
	$null -ne $command
}

function Test-Vim() {
	Test-AppCommandPath 'vim'
}

function Test-Argo() {
	Test-AppCommandPath 'argo'
}

function Get-KubectlContexts([switch] $nameOnly) {

	$output = @()
	if ($nameOnly) {
		$output = '-o','name'
	}
	$contexts = kubectl config get-contexts @($output)
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to get kubectl contexts, kubectl exited with code $LASTEXITCODE."
	}
	$contexts
}

$choices = @(

	@{id="A1"; name='Show All Workflows';
		action={
			argo -n $toolOrchestrationNamespace list --instanceid $toolOrchestrationReleaseName | sort-object
		};
		valid = {$toolOrchestrationNamespace -ne '' -and (Test-Argo)}
	}

	@{id="A2"; name='Show All Workflow Details';
		action={
			argo -n $toolOrchestrationNamespace list --instanceid $toolOrchestrationReleaseName -o name | sort-object | ForEach-Object {
				write-host "`n--------$_--------" -fore red
				argo -n $toolOrchestrationNamespace get --instanceid $toolOrchestrationReleaseName $_
			}
		};
		valid = {$toolOrchestrationNamespace -ne '' -and (Test-Argo)}
	}

	@{id="A3"; name='Show Running Workflows';
		action={
			argo -n $toolOrchestrationNamespace list --instanceid $toolOrchestrationReleaseName --running | sort-object
		};
		valid = {$toolOrchestrationNamespace -ne '' -and (Test-Argo)}
	}

	@{id="A4"; name='Show Running Workflow Details';
		action={
			argo -n $toolOrchestrationNamespace list --instanceid $toolOrchestrationReleaseName --running -o name | ForEach-Object {
				write-host "`n--------$_--------" -fore red
				argo -n $toolOrchestrationNamespace get --instanceid $toolOrchestrationReleaseName $_
			}
		};
		valid = {$toolOrchestrationNamespace -ne '' -and (Test-Argo)}
	}

	@{id="A5"; name='Show Workflow Detail';
		action={
			$workflowName = read-host -prompt 'Enter workflow ID'
			argo -n $toolOrchestrationNamespace get --instanceid $toolOrchestrationReleaseName $workflowName
		};
		valid = {$toolOrchestrationNamespace -ne '' -and (Test-Argo)}
	}

	@{id="C1"; name='Get Code Dx Namespace Pods';
		action={
			kubectl -n $codedxNamespace get pod -o wide
		};
		valid = {$codedxNamespace -ne ''}
	}

	@{id="C2"; name='Watch Code Dx Namespace Pods (Ctrl+C to quit - script restart required)';
		action={
			kubectl -n $codedxNamespace get pod -o wide -w
		};
		valid = {$codedxNamespace -ne ''}
	}

	@{id="C3"; name='Describe Code Dx Pod';
		action={
			kubectl -n $codedxNamespace -l app=codedx describe pod
		};
		valid = {$codedxNamespace -ne ''}
	}

	@{id="C4"; name='Get Code Dx Projects';
		action={
			(Invoke-RestMethod -SkipCertificateCheck:$codedxSkipCertificateCheck -Headers @{"API-Key"=$codedxAdminApiKey} -Uri "$codedxBaseUrl/api/projects").projects
		};
		valid = {$codedxAdminApiKey -ne '' -and $codedxBaseUrl -ne ''}
	}

	@{id="D1"; name='Delete *all* Code Dx Projects';
		action={
			if (Get-Confirmation $codedxAdminApiKey) {
				(Invoke-RestMethod -SkipCertificateCheck:$codedxSkipCertificateCheck -Headers @{"API-Key"=$codedxAdminApiKey} -Uri "$codedxBaseUrl/api/projects").projects.id | ForEach-Object {
					if ($null -ne $_) {
						Invoke-RestMethod -SkipCertificateCheck:$codedxSkipCertificateCheck -Headers @{"API-Key"=$codedxAdminApiKey} -Method Delete -Uri "$codedxBaseUrl/api/projects/$_"
					}
				}
			}
		};
		valid = {$codedxAdminApiKey -ne '' -and $codedxBaseUrl -ne ''}
	}

	@{id="D2"; name='Delete Code Dx Deployment';
		action={
			if (Get-Confirmation $codedxReleaseName) {
				helm delete -n $codedxNamespace $codedxReleaseName
			}
		};
		valid = {$codedxNamespace -ne '' -and $codedxReleaseName -ne ''}
	}

	@{id="D3"; name='Delete Tool Orchestration Deployment';
		action={
			if (Get-Confirmation $toolOrchestrationReleaseName) {
				helm delete -n $toolOrchestrationNamespace $toolOrchestrationReleaseName
			}
		};
		valid = {$toolOrchestrationNamespace -ne '' -and $toolOrchestrationReleaseName -ne ''}
	}

	@{id="H1"; name='Show All Helm Depoloyments';
		action={
			helm list --all-namespaces
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="K1"; name='Get All Pods';
		action={
			kubectl get pod -A -o wide
		};
		valid = {$true}
	}

	@{id="L1"; name='Show Code Dx Log';
		action={
			$podName = kubectl -n $codedxNamespace get pod -l app=codedx -o name
			kubectl -n $codedxNamespace logs $podName
		};
		valid = {$codedxNamespace -ne ''}
	}

	@{id="L2"; name='Open Code Dx Log in vim';
		action={
			$podName = kubectl -n $codedxNamespace get pod -l app=codedx -o name
			kubectl -n $codedxNamespace logs $podName | vim -
		};
		valid = {$codedxNamespace -ne '' -and (Test-Vim)}
	}

	@{id="L3"; name='Show Code Dx Log (ERRORs)';
		action={
			$podName = kubectl -n $codedxNamespace get pod -l app=codedx -o name
			kubectl -n $codedxNamespace logs $podName | Select-String '^ERROR\s'
		};
		valid = {$codedxNamespace -ne ''}
	}

	@{id="L4"; name='Show Code Dx Log (Last 10 Minutes)';
		action={
			$podName = kubectl -n $codedxNamespace get pod -l app=codedx -o name
			kubectl -n $codedxNamespace logs --since=10m $podName
		};
		valid = {$codedxNamespace -ne ''}
	}

	@{id="L5"; name='Show Tool Orchestration Log(s)';
		action={
			kubectl -n $toolOrchestrationNamespace get pod -l component=service -o name | ForEach-Object {
				write-host "`n--------$_--------" -fore red
				kubectl -n $toolOrchestrationNamespace logs $_
			}
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="L6"; name='Open Tool Orchestration Log(s) in vim';
		action={
			kubectl -n $toolOrchestrationNamespace get pod -l component=service -o name | ForEach-Object {
				write-host "`n--------$_--------" -fore red
				kubectl -n $toolOrchestrationNamespace logs $_ | vim -
			}
		};
		valid = {$toolOrchestrationNamespace -ne '' -and (Test-Vim)}
	}

	@{id="L7"; name='Show Tool Orchestration Log(s) (Last 10 Minutes)';
		action={
			kubectl -n $toolOrchestrationNamespace get pod -l component=service -o name | ForEach-Object {
				write-host "`n--------$_--------" -fore red
				kubectl -n $toolOrchestrationNamespace logs --since=10m $_
			}
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="L8"; name='Show Tool Orchestration log(s) (HTTP Status Code 500)';
		action={
			kubectl -n $toolOrchestrationNamespace get pod -l component=service -o name | ForEach-Object {
				write-host "`n--------$_--------" -fore red
				kubectl -n $toolOrchestrationNamespace logs $_ | Select-String 'Status Code: 500' -SimpleMatch
			}
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="L9"; name='Show Auto Scaler Log';
		action={
			$name = kubectl -n kube-system get deployment cluster-autoscaler -o name
			if ($null -eq $name) {
				write-host 'Cannot find cluster-autoscaler deployment!'
			} else {
				kubectl -n kube-system logs deployment/cluster-autoscaler
			}
		}
		valid={$true}
	}

	@{id="M1"; name='Describe MinIO Pod';
		action={
			kubectl -n $toolOrchestrationNamespace describe pod -l app.kubernetes.io/name=minio
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="M2"; name='Port-Forward MinIO Pod (Ctrl+C to quit - script restart required)';
		action={
			$minIOPodName = kubectl -n $toolOrchestrationNamespace get pod -l app.kubernetes.io/name=minio -o name
			if ($null -eq $minIOPodName) {
				Write-Host 'Cannot find MinIO pod!'
			} else {
				Write-Host 'Configuring localhost to port-forward to MinIO using http://localhost:9000...'
				kubectl -n $toolOrchestrationNamespace port-forward $minIOPodName 9000
			}
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="N1"; name='Get Nodes';
		action={
			kubectl get node
		};
		valid = {$true}
	}

	@{id="R1"; name='Replace Code Dx Pod';
		action={
			$deploymentName = Get-CodeDxChartFullName $codedxReleaseName
			kubectl -n $codedxNamespace scale --replicas=0 "deployment/$deploymentName"
			kubectl -n $codedxNamespace scale --replicas=1 "deployment/$deploymentName"
		};
		valid = {$codedxNamespace -ne '' -and $codedxReleaseName -ne ''}
	}

	@{id="R2"; name='Replace Tool Orchestration Pod(s)';
		action={
			$replicaCount = (Get-HelmValues $toolOrchestrationNamespace $toolOrchestrationReleaseName).numReplicas

			$deploymentName = Get-CodeDxToolOrchestrationChartFullName $toolOrchestrationReleaseName
			kubectl -n $toolOrchestrationNamespace scale --replicas=0             "deployment/$deploymentName"
			kubectl -n $toolOrchestrationNamespace scale --replicas=$replicaCount "deployment/$deploymentName"
		};
		valid = {$toolOrchestrationNamespace -ne '' -and $toolOrchestrationReleaseName -ne ''}
	}

	@{id="R3"; name='Replace MariaDB Pod(s)';
		action={
			$deploymentNamePrefix = Get-MariaDbChartFullName $codedxReleaseName
			kubectl -n $codedxNamespace scale --replicas=0 "statefulset/$deploymentNamePrefix-master"
			kubectl -n $codedxNamespace scale --replicas=1 "statefulset/$deploymentNamePrefix-master"

			$subordinateCount = (Get-HelmValues $codedxNamespace $codedxReleaseName).mariadb.slave.replicas
			kubectl -n $codedxNamespace scale --replicas=0                 "statefulset/$deploymentNamePrefix-slave"
			kubectl -n $codedxNamespace scale --replicas=$subordinateCount "statefulset/$deploymentNamePrefix-slave"
		};
		valid = {$codedxNamespace -ne '' -and $codedxReleaseName -ne '' -and (Get-HelmValues $codedxNamespace $codedxReleaseName).mariadb.enabled}
	}

	@{id="R4"; name='Replace MinIO Pod';
		action={
			$deploymentName = Get-MinIOChartFullName $toolOrchestrationReleaseName
			kubectl -n $toolOrchestrationNamespace scale --replicas=0 "deployment/$deploymentName"
			kubectl -n $toolOrchestrationNamespace scale --replicas=1 "deployment/$deploymentName"
		};
		valid = {$toolOrchestrationNamespace -ne '' -and $toolOrchestrationReleaseName -ne ''}
	}

	@{id="S1"; name='Shut Down Code Dx Deployment';
		action={
			$deploymentName = Get-CodeDxChartFullName $codedxReleaseName
			kubectl -n $codedxNamespace scale --replicas=0 "deployment/$deploymentName"
		};
		valid = {$codedxNamespace -ne '' -and $codedxReleaseName -ne ''}
	}

	@{id="S2"; name='Shut Down Tool Orchestration Deployment';
		action={
			$deploymentName = Get-CodeDxToolOrchestrationChartFullName $toolOrchestrationReleaseName
			kubectl -n $toolOrchestrationNamespace scale --replicas=0 "deployment/$deploymentName"
		};
		valid = {$toolOrchestrationNamespace -ne '' -and $toolOrchestrationReleaseName -ne ''}
	}

	@{id="S3"; name='Shut Down MariaDB StatefulSet(s)';
		action={
			$deploymentNamePrefix = Get-MariaDbChartFullName $codedxReleaseName
			kubectl -n $codedxNamespace scale --replicas=0 "statefulset/$deploymentNamePrefix-master"
			$subordinateCount = (Get-HelmValues $codedxNamespace $codedxReleaseName).mariadb.slave.replicas
			if ($subordinateCount -gt 0) {
				kubectl -n $codedxNamespace scale --replicas=0 "statefulset/$deploymentNamePrefix-slave"
			}
		};
		valid = {$codedxNamespace -ne '' -and $codedxReleaseName -ne '' -and (Get-HelmValues $codedxNamespace $codedxReleaseName).mariadb.enabled}
	}

	@{id="S4"; name='Shut Down MinIO Deployment';
		action={
			$deploymentName = Get-MinIOChartFullName $toolOrchestrationReleaseName
			kubectl -n $toolOrchestrationNamespace scale --replicas=0 "deployment/$deploymentName"
		};
		valid = {$toolOrchestrationNamespace -ne '' -and $toolOrchestrationReleaseName -ne ''}
	}

	@{id="T1"; name='Get Tool Orchestration Namespace Pods';
		action={
			kubectl -n $toolOrchestrationNamespace get pod -o wide
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="T2"; name='Watch Tool Orchestration Namespace Pods (Ctrl+C to quit - script restart required)';
		action={
			kubectl -n $toolOrchestrationNamespace get pod -o wide -w
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}

	@{id="T3"; name='Describe Tool Orchestration Pod(s)';
		action={
			kubectl -n $toolOrchestrationNamespace describe pod -l component=service
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}


	@{id="T4"; name='Describe Resource Requirement(s)';
		action={
			kubectl -n $toolOrchestrationNamespace describe cm cdx-toolsvc
		};
		valid = {$toolOrchestrationNamespace -ne ''}
	}
)

$kubeContexts = Get-KubectlContexts -nameOnly
if ($kubeContexts.count -eq 0) {
	Write-Host 'Unable to find any kubectl contexts. Are you connected to your cluster?'
	exit 2
}

if ($kubeContext -eq '' -or $kubeContexts -notcontains $kubeContext) {

	Write-Host "`nHere are your kubectl contexts:`n"
	$kubeContexts | ForEach-Object {
		Write-Host "  $_"
	}
	$kubeContext = Read-Host -Prompt "`nEnter the name of the kubectl context for your cluster"
}

kubectl config use-context $kubeContext
if ($LASTEXITCODE -ne 0) {
	Write-Host "Failed to switch to '$kubeContext' kube context."
	Write-Host 'Run kubectl config get-contexts to see whether you are connected to your cluster.'
	Write-Host "You must have a context named '$kubeContext' or you must run this program with a different '-kubeContext' parameter value."
	Write-Host "You can also rename your current context to '$kubeContext' by running kubectl config rename-context."
	exit 2
}

if (-not (Test-HelmRelease $codedxNamespace $codedxReleaseName)) {
	Write-Host "Unable to find Helm release named $codedxReleaseName in namespace $codedxNamespace."
	exit 2
}

if ($toolOrchestrationNamespace -ne '' -and (-not (Test-HelmRelease $toolOrchestrationNamespace $toolOrchestrationReleaseName))) {
	Write-Host "Unable to find Helm release named $toolOrchestrationReleaseName in namespace $toolOrchestrationNamespace."
	exit 2
}

Write-Host 'Loading...'

$cmdCount = $choices.count
$choices = $choices | Where-Object { & $_.valid } | Sort-Object -Property id
$missingCmds = $cmdCount -ne $choices.count

$choices = $choices + @{id="QA"; name='Quit'; action={ exit }} 

$choice = ''
$awaitingChoice = $false
while ($true) {

	if (-not $awaitingChoice) {
		Write-Choices $choices
		$awaitingChoice = $true
	}

	if ($missingCmds) {
		Write-Host "Note: The specified script parameter values made one or more actions unavailable.`n"
		$missingCmds=$false
	}

	if ('' -eq $choice) {
		$choice = read-host -prompt 'Enter code (e.g., C1)'
	}

	$action = $choices | Where-Object {
		$_.id -eq $choice
	}

	if ($null -eq $action) {
		$choice = ''
		Write-Host 'Try again by specifying a choice from the above list (enter QA to quit)'
		continue
	}

	Write-Host "`n$($action.name)...`n"
	& $action.action
	Write-Host "`n---"

	$choice = Read-Host 'Specify another command or press Enter to continue...'
	if ('' -ne $choice -and ($choices | select-object -ExpandProperty id) -notcontains $choice) {
		Write-Host 'Invalid choice'
		$choice = ''
	}

	$awaitingChoice = '' -ne $choice
}
