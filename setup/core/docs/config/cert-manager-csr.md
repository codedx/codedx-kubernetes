# Configure Cert-Manager Certficate Signing Requests

Here are the steps to configure a cert-manager signer for Kubernetes Certificate Signing Requests (CSR).

>Note: The cert-manager support for Kubernetes CSRs is in an experimental state.

## Install Cert-Manager

1) Install the cert-manager CRDs by [running kubectl apply](https://cert-manager.io/docs/installation/helm/#3-install-customresourcedefinitions).

2) Follow the [installation instructions](https://cert-manager.io/docs/usage/kube-csr/) to install cert-manager using its Helm chart with the flag to enable the experimental CSR feature.

>Note: You can install the cert-manager CRDs via the Helm chart by using `--set installCRDs=true`.

## Configure Cert-Manager

With cert-manager installed, you can configure one of the internal issuers (with API version `cert-manager.io/v1`).

Refer to the [Issuer Configuration](https://cert-manager.io/docs/configuration/) documentation to create either a ClusterIssuer or Issuer resources.

## Example: CA Issuer with ClusterIssuer

This section provides an example of using a [CA issuer](https://cert-manager.io/docs/configuration/ca/) with a [ClusterIssuer resource](https://cert-manager.io/docs/configuration/).

1) Run the following commands to create a signing key and certificate with the common name `Private CA`:

```bash
openssl genrsa -out ca.key 2048
openssl req -x509 -new -key ca.key -subj "/CN=Private CA" -days 3650 -out ca.crt
```

2) Run the following command to create a Kubernetes Secret named `ca-key-pair`:

```bash
kubectl -n cert-manager create secret tls ca-key-pair --cert=ca.crt --key=ca.key
```

>Note: The above kubectl command creates a Kubernetes Secret in the cert-manager namespace because this example uses a ClusterIssuer. Creating an Issuer in a specific namespace would mean creating a Kubernetes secret in that namespace. If you plan to use one signer for components in the Code Dx namespace and another for components in the Tool Orchestration namespace, make sure that both signers use the same root CA.

3) Create a new file named `clusterissuer.yaml` with the following contents:

```bash
apiVersion: cert-manager.io/v1
kind: ClusterIssuer
metadata:
  name: ca-issuer
spec:
  ca:
    secretName: ca-key-pair
```

4) Run the following command to create the `ca-issuer` ClusterIssuer:

```bash
kubectl apply -f ./clusterissuer.yaml
```

5) Continue running the following command until the `ca-issuer` resource shows a ready status:

```bash
kubectl get clusterissuer ca-issuer -o wide
```

6) With your ClusterIssuer in a ready state, you can now use it with the Code Dx deployment script to provision certificates.

If you already installed Code Dx using a different signer (e.g., kubernetes.io/legacy-unknown) and are switching to cert-manager, open your run-setup.ps1 file and update the following parameters:

```
-csrSignerNameCodeDx 'clusterissuers.cert-manager.io/ca-issuer'
-csrSignerNameToolOrchestration 'clusterissuers.cert-manager.io/ca-issuer'
-clusterCertificateAuthorityCertPath '/path/to/ca.crt'
```

If you have not yet installed Code Dx, provide these answers to the following certificate-related Guided Setup prompts:

```
Enter the file path for your Kubernetes CA cert: /path/to/ca.crt
Enter the Code Dx components CSR signerName: clusterissuers.cert-manager.io/ca-issuer
Enter the Code Dx Tool Orchestration components CSR signerName: clusterissuers.cert-manager.io/ca-issuer
```

7) Now it's time to run the Code Dx deployment script. If you already installed Code Dx, rerun your run-setup.ps1 script and when the script completes, restart the deployments/statefulsets to ensure they run with the latest certificates:

```
kubectl -n cdx-app scale --replicas=0 deployment/codedx
kubectl -n cdx-app scale --replicas=0 statefulset/codedx-mariadb-slave
kubectl -n cdx-app scale --replicas=0 statefulset/codedx-mariadb-master

kubectl -n cdx-svc scale --replicas=0 deployment/codedx-tool-orchestration
kubectl -n cdx-svc scale --replicas=0 deployment/codedx-tool-orchestration-minio

kubectl -n cdx-svc scale --replicas=1 deployment/codedx-tool-orchestration-minio
kubectl -n cdx-svc scale --replicas=1 deployment/codedx-tool-orchestration

kubectl -n cdx-app scale --replicas=1 statefulset/codedx-mariadb-master
kubectl -n cdx-app scale --replicas=1 statefulset/codedx-mariadb-slave
kubectl -n cdx-app scale --replicas=1 deployment/codedx
```

>Note: If you use alternate namespaces or a different replica count for the codedx-tool-orchestration deployment, adjust the above commands. Ignore the cdx-svc commands if you're not using the Tool Orchestration feature.