
# Azure Setup Script

The setup.ps1 PowerShell Core script uses Helm to install and configure Code Dx and Tool Orchestration on an Azure AKS cluster.

## Prerequisites

This script is compatible with a cluster running Kubernetes v1.14. You must install PowerShell Core before running setup.ps1. The following tools must be installed and included in your PATH before running setup.ps1:

- [helm 3.0](https://helm.sh/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (for Kubernetes 1.14.6)
- [openssl](https://www.openssl.org/)
- [git](https://git-scm.com/)
- [keytool](https://adoptopenjdk.net/installation.html)

>Note: The setup.ps1 script currently requires a private Docker registry.

You will also need access to a Domain Name System where you can register an entry for your Code Dx domain name. The setup script will configure https access to the Code Dx web applicaiton using the Let's Encrypt certificate authority.

## Setup Azure Cluster

You can use the resources/create-cluster.sh script to create an AKS cluster. You should also enable Pod Security Policies on your AKS cluster.

Use the az command to connect to your Kubernetes cluster. Run the following command after specifying the cluster's resource group and name.

```
az aks get-credentials --resource-group <resource-group> --name <cluster-name>
```

Once your new k8s cluster is online, create a public IP address in your Azure subscription and add it to the resource group created for your cluster that includes your node pool (not the resource group used in the above get-credentials command). Then create a new domain name A record that maps your Code Dx domain name to your static IP address.

>Note: If you want to reuse an existing IP address from your Azure subscription, you must move it into the resource group created for your cluster so that the ingress can initialize properly.

You will need to download the CA certificate for your cluster. Use a terminal window (with support for kubectl run -it) to create and switch to a new directory where you will fetch the CA cert. Run the following commands in order using a second terminal window, running from your new directory, to complete the steps.

```
From Terminal 1: kubectl run --rm=true -it busybox --image=busybox --restart=Never
From Terminal 1: / # cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /tmp/azure-aks.pem
From Terminal 2: kubectl cp busybox:/tmp/azure-aks.pem ./azure-aks.pem
From Terminal 1: exit
```

The last command will delete the busybox pod and exit the session you started in the first terminal. You should now have an azure-aks.pem file in the directory where you invoked the second terminal window.

## Install Code Dx and Tool Orchestration

Before running the setup.ps1 script, you must download all of the .ps1 files under the codedx-kubernetes/setup directory. You can clone this repository to download the required files.

Start a new PowerShell Core shell with the following command.

```
pwsh
```

From your running PowerShell Core shell, run the following command by replacing required command-line parameters where necessary.

```
./setup.ps1 `
  -codeDxDnsName '<dns-name>' `
  -clusterCertificateAuthorityCertPath '<path-to-azure-aks.pem>' `
  -minioAdminPwd '<minio-password>' `
  -mariadbRootPwd '<mariadb-root-password>' `
  -mariadbReplicatorPwd '<mariadb-replication-password>' `
  -codedxAdminPwd '<codedx-admin-password>' `
  -dockerConfigJson '<docker-config-json>' `
  -ingressRegistrationEmailAddress '<email-address>' `
  -ingressLoadBalancerIP '<static-ip>'
```

## Post Setup Tasks

The setup.ps1 script configures Code Dx for the Let's Encrypt staging environment. You can switch from the staging environment to the production environment by running the following command after specifing the correct ingress and namespace name. Do not make the switch until you are certain that the Code Dx application runs correctly with the certificate issued by the staging environment.

```
kubectl -n <code-dx-namespace> annotate ingress <coded-dx-ingress-name> cert-manager.io/cluster-issuer='letsencrypt-prod' --overwrite
```

## Cleanup

You can delete the Azure cluster by running the following command after specifying the resource group and cluster name.

```
az aks delete --name <name> --resource-group <resource-group>
```
