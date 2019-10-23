
# Minikube Setup Script

The setup.ps1 PowerShell Core script uses Helm to install and configure Code Dx and Tool Orchestration on a minikube cluster.

## Prerequisites

The following tools must be installed and included in your PATH before running setup.ps1:

- minikube
- helm
- kubectl
- openssl
- git
- keytool

>Note: The setup.ps1 script currently supports Windows only and requires a private Docker registry.

## Setup

Run setup.ps1 with the following command:

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
