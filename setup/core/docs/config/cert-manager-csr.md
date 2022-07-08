# Configure Cert-Manager Certficate Signing Requests

Here are the steps to configure a cert-manager signer for Kubernetes Certificate Signing Requests (CSR).

>Note: The cert-manager support for Kubernetes CSRs is in an experimental state.

## Install Cert-Manager

This section describes how to install cert-manager with the `ExperimentalCertificateSigningRequestControllers` feature. If you previously installed cert-manager without enabling ExperimentalCertificateSigningRequestControllers, update your cert-manager deployment before continuing by running helm upgrade with --set featureGates="ExperimentalCertificateSigningRequestControllers=true".

1) Install the cert-manager CRDs by [running kubectl apply](https://cert-manager.io/docs/installation/helm/#3-install-customresourcedefinitions). If you want to install the cert-manager CRDs via the cert-manager Helm cart, skip this step and append `--set installCRDs=true` to the helm install command referenced in the next step.

2) Follow the [kube-csr installation instructions](https://cert-manager.io/docs/usage/kube-csr/) to install cert-manager using its Helm chart with the flag to enable the experimental CSR feature.

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

5) Continue running the following command until the `ca-issuer` resource shows a Ready status:

```bash
kubectl get clusterissuer ca-issuer -o wide
```

6) With your ClusterIssuer ready, you can reference it from the Code Dx Guided Setup by providing these answers to the following certificate-related Guided Setup prompts:

```
Enter the file path for your Kubernetes CA cert: /path/to/ca.crt
Enter the Code Dx components CSR signerName: clusterissuers.cert-manager.io/ca-issuer
Enter the Code Dx Tool Orchestration components CSR signerName: clusterissuers.cert-manager.io/ca-issuer
```

7) When the Code Dx Guided Setup completes, run the deployment script(s) to provision certificates using a cert-manager CSR signer.
