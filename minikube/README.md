
# Minikube Setup Script

The setup.ps1 PowerShell Core script uses Helm to install and configure Code Dx and Tool Orchestration on a minikube cluster.

## Prerequisites

You must install PowerShell Core before running setup.ps1. The following tools must be installed and included in your PATH before running setup.ps1:

- [minikube](https://kubernetes.io/docs/tasks/tools/install-minikube) ([VirtualBox](https://www.virtualbox.org/wiki/Downloads) preferred)
- [helm 2.0](https://helm.sh/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (for Kubernetes 1.14.6)
- [openssl](https://www.openssl.org/)
- [git](https://git-scm.com/)
- [keytool](https://adoptopenjdk.net/installation.html)

>Note: The setup.ps1 script currently requires a private Docker registry.

## Setup Minikube Cluster

Before running the setup.ps1 script, you must download all of the .ps1 files in this directory. You can clone this repository to download the required files.

Run setup.ps1 with the following command. 

>Note: On Windows, you must run this from an elevated Command Prompt.

```
pwsh ./setup.ps1
```

You can use the default values for many of the setup.ps1 script parameters. When running the script for the first time, you must specify values for the following parameters when prompted.

| Parameter | Description | Example |
|---|---|---|
| codeDxAdminPwd | The password for the Code Dx admin account. | R8Cx3o$ptVQ1 |
| minioAdminUsername | The username of the admin MinIO account. | 55XX08PR$lpO |
| minioAdminPwd | The password for the admin MinIO account. | y@w#Bn$$3M2q |
| toolServiceApiKey | The API key protecting admin endpoints of the Tool Orchestration service. | fb9a70bc-4049-4250-a676-b4194c34ac09 |
| dockerConfigJson | The .dockerconfigjson value allowing access to a private Docker registry. | See .dockerconfigjson at https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/#registry-secret-existing-credentials |

When the script completes, you can start using Code Dx. You can make the Code Dx web application available on port 8080 by running the following commands.

```
pwsh
$podName = kubectl -n cdx-app get pod -l app=codedx --field-selector=status.phase=Running -o name
kubectl -n cdx-app port-forward $podName 8080
```

>Note: You must enter a valid license before using the Code Dx Tool Orchestration software.

## Stop Minikube Cluster

You can stop the minikube cluster created by setup.ps1 with the following minikube command.

>Note: This command assumes that you used 'minikube-1-14-6' for the value of the $minikubeProfile setup.ps1 script parameter.

```
minikube -p minikube-1-14-6 stop
```

## Restart Minikube Cluster

Restart the minikube cluster created by setup.ps1 with the following command.

```
pwsh ./setup.ps1
```

When the script completes, you can start using Code Dx. You can make the Code Dx web application available on port 8080 by running the following commands.

```
pwsh
kubectl -n cdx-app port-forward (kubectl -n cdx-app get pod -l app=codedx --field-selector=status.phase=Running -o name) 8080
```


## Delete Minikube Cluster

You can delete the minikube cluster created by setup.ps1 with the following minikube command.

>Note: This command assumes that you used 'minikube-1-14-6' for the value of the $minikubeProfile setup.ps1 script parameter.

```
minikube -p minikube-1-14-6 delete
```
