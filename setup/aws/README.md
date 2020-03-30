
# AWS EKS Setup Script

The setup.ps1 PowerShell Core script uses Helm to install and configure Code Dx and Tool Orchestration on an AWS EKS cluster.

## Prerequisites

This script is compatible with a cluster running Kubernetes v1.14. You must install PowerShell Core before running setup.ps1. The following tools must be installed and included in your PATH before running setup.ps1:

- [helm 3.0](https://helm.sh/docs/install)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/) (for Kubernetes 1.14.6)
- [openssl](https://www.openssl.org/)
- [git](https://git-scm.com/)
- [keytool](https://adoptopenjdk.net/installation.html)

>Note: The setup.ps1 script currently requires a private Docker registry.

You will also need access to a Domain Name System where you can register an entry for your Code Dx domain name. The setup script will configure https access to the Code Dx web applicaiton using the Let's Encrypt certificate authority.

## Setup EKS Cluster

You can use the resources/create-cluster.sh script to create an EKS cluster.

Once your new k8s cluster is online, open the EKS AWS console and download the base64 representation of your cluster's CA certificate. You can generate a aws-eks.pem file by running the following command after specifying the base64-encoded certificate data shown in the console.

```
echo '<base64-encoded-certificate-data>' | base64 -d > aws-eks.pem
```

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
  -clusterCertificateAuthorityCertPath '<path-to-aws-eks.pem>' `
  -minioAdminPwd '<minio-password>' `
  -mariadbRootPwd '<mariadb-root-password>' `
  -mariadbReplicatorPwd '<mariadb-replication-password>' `
  -codedxAdminPwd '<codedx-admin-password>' `
  -dockerConfigJson '<docker-config-json>' `
  -ingressRegistrationEmailAddress '<email-address>'
```

## Post Setup Tasks

To access Code Dx by the domain name you specified, create a new CNAME DNS record that maps your Code Dx domain name to the public DNS name associated with the nginx ingress controller service. Run the following command after specifying the correct nginx namespace (nginx is the default) to find the public DNS name under EXTERNAL-IP.

```
kubectl -n <nginx-namespace> get svc nginx-nginx-ingress-controller
```

The setup.ps1 script configures Code Dx for the Let's Encrypt staging environment. You can switch from the staging environment to the production environment by rerunning setup.ps1. Do not make the switch until you are certain that the Code Dx application runs correctly with the certificate issued by the staging environment. When you're ready, rerun setup.ps1 with the same parameter set and include a new parameter named ingressClusterIssuer with value letsencrypt-prod like in the following example.

```
./setup.ps1 `
  -codeDxDnsName '<dns-name>' `
  -clusterCertificateAuthorityCertPath '<path-to-aws-eks.pem>' `
  -minioAdminPwd '<minio-password>' `
  -mariadbRootPwd '<mariadb-root-password>' `
  -mariadbReplicatorPwd '<mariadb-replication-password>' `
  -codedxAdminPwd '<codedx-admin-password>' `
  -dockerConfigJson '<docker-config-json>' `
  -ingressRegistrationEmailAddress '<email-address>' `
  -ingressClusterIssuer 'letsencrypt-prod'
```

## Installing Updates

You can rerun your setup.ps1 script to install updates or change configuration parameters. Always restart the Code Dx deployments after rerunning setup.ps1 to make sure that components use updated dependencies like configuration maps.

## Cleanup

You can delete the EKS cluster by running the following command after specifying the cluster name.

```
eksctl delete cluster --name <cluster-name>
```
