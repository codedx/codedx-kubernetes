param(
    [string] $kubeContext = 'eks',
    [string] $codedxNamespace = 'cdx-app',
    [string] $codedxReleaseName = 'codedx-app',
    [string] $codedxBaseUrl = '',
    [bool]   $codedxSkipCertificateCheck = $false,
    [string] $codedxAdminApiKey = '',
    [string] $toolOrchestrationNamespace = 'cdx-svc',
    [string] $toolOrchestrationReleaseName = 'toolsvc'
)

$ErrorActionPreference = 'Stop'
Set-PSDebug -Strict

$toolOrchestrationNamespace -ne ''

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

$choices = @(

    @{id="A1"; name='Show All Workflows'; 
        action={ 
            argo -n $toolOrchestrationNamespace list
        };
        valid = {$toolOrchestrationNamespace -ne ''} 
    }  

    @{id="A2"; name='Show All Workflow Details'; 
        action={ 
            argo -n $toolOrchestrationNamespace list -o name | ForEach-Object {
                write-host "`n--------$_--------" -fore red
                argo -n $toolOrchestrationNamespace get $_
            }
        };
        valid = {$toolOrchestrationNamespace -ne ''} 
    }  

    @{id="A3"; name='Show Running Workflows'; 
        action={ 
            argo -n $toolOrchestrationNamespace list --running
        };
        valid = {$toolOrchestrationNamespace -ne ''}  
    }    

    @{id="A4"; name='Show Running Workflow Details'; 
        action={ 
            argo -n $toolOrchestrationNamespace list --running -o name | ForEach-Object {
                write-host "`n--------$_--------" -fore red
                argo -n $toolOrchestrationNamespace get $_
            }
        };
        valid = {$toolOrchestrationNamespace -ne ''}  
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

    @{id="L2"; name='Open Code Dx Log in vim (requires vim)'; 
        action={ 
            $podName = kubectl -n $codedxNamespace get pod -l app=codedx -o name
            kubectl -n $codedxNamespace logs $podName | vim -
        };
        valid = {$codedxNamespace -ne ''} 
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

    @{id="L6"; name='Open Tool Orchestration Log(s) in vim (requires vim)'; 
        action={ 
            kubectl -n $toolOrchestrationNamespace get pod -l component=service -o name | ForEach-Object { 
                write-host "`n--------$_--------" -fore red
                kubectl -n $toolOrchestrationNamespace logs $_ | vim -
            } 
        };
        valid = {$toolOrchestrationNamespace -ne ''}
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
            kubectl -n $codedxNamespace scale --replicas=0 "deployment/$codedxReleaseName-codedx"
            kubectl -n $codedxNamespace scale --replicas=1 "deployment/$codedxReleaseName-codedx"
        };
        valid = {$codedxNamespace -ne ''} 
    }    

    @{id="R2"; name='Replace Tool Orchestration Pod(s)'; 
        action={ 
            $podNames = kubectl -n $toolOrchestrationNamespace get pod -l component=service -o name
            kubectl -n $toolOrchestrationNamespace scale --replicas=0 "deployment/$toolOrchestrationReleaseName-codedx-tool-orchestration"
            kubectl -n $toolOrchestrationNamespace scale --replicas=$($podNames.count) "deployment/$toolOrchestrationReleaseName-codedx-tool-orchestration"
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
)

kubectl config use-context $kubeContext
if ($LASTEXITCODE -ne 0) {
    Write-Host "Failed to switch to '$kubeContext' kube context."
    Write-Host 'Run kubectl config get-contexts to see whether you are connected to your EKS cluster.'
    Write-Host "You must have a context named '$kubeContext' or you must run this program with a different '-kubeContext' parameter value."
    Write-Host "You can also rename your current EKS context to '$kubeContext' by running kubectl config rename-context."
    exit 2
}

$cmdCount = $choices.count
$choices = $choices | Where-Object { & $_.valid } | Sort-Object -Property id
$missingCmds = $cmdCount -ne $choices.count

$choices = $choices + @{id="QA"; name='Quit'; action={ exit }} 

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

    $choice = read-host -prompt 'Enter code (e.g., A1)'
    $action = $choices | Where-Object { 
        $_.id -eq $choice 
    }

    if ($null -eq $action) {
        Write-Host 'Try again by specifying a choice from the above list (enter QA to quit)'
        continue
    }

    Write-Host "`n$($action.name)...`n"
    & $action.action
    Write-Host "`n---"

    Read-Host 'Press Enter to continue...'
    $awaitingChoice = $false
}
