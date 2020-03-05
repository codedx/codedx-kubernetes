
# Code Dx Tool Orchestration

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

The Code Dx Tool Orchestration Helm chart installs the Code Dx components that can orchestrate analyses that run in whole or in part on your Kubernetes (k8s) cluster. Since Code Dx Tool Orchestration depends on Code Dx, you must install Code Dx first. Then you can install Code Dx Tool Orchestration and update your Code Dx deployment to use the Tool Orchestration service.

## Prerequisite Details

- Kubernetes v1.14 (v1.16 unsupported)
- Helm v3
- Code Dx license with Orchestration feature ([purchase](https://codedx.com/purchase-application/) or [request a free trial](https://codedx.com/free-trial/))

### Tool Orchestration Namespace

The use of a separate namespace for Tool Orchestration components is strongly recommended. This document assumes a cdx-svc namespace name, but you can substitute your own namespace name if you decide on a different one. Create your namespace with the following command.

```
kubectl create namespace cdx-svc
```

### Code Dx

This document assumes that you have installed Code Dx in a separate Kubernetes namespace and that you have the base URL for your Code Dx installation. If you have not installed Code Dx, follow the Code Dx Kubernetes installation instructions at this time. This document assumes that your Code Dx namespace is cdx-app created with the following command.

```
kubectl create namespace cdx-app
```

This document also assumes that the Kubernetes namespace where Code Dx is installed has the label name=cdx-app. If you have not yet applied a namespace label to the Kubernetes namespace where Code Dx is installed, do so now with the following command.

```
kubectl label namespace cdx-app name=cdx-app
```

### TLS Configuration

The use of TLS for Tool Orchestration service and MinIO server connections is strongly recommended. The names of your endpoints get derived from the Helm release name you specify, so choose a release name before continuing. This document assumes a toolsvc release name, but you can substitute your own name if you decide on different one.

You will need to create certificates for both the Tool Orchestration service and the MinIO server with the host names listed below. To use the CA from your Kubernetes cluster, follow [these instructions](CreateCertificates.md).

MinIO Host Names:

- toolsvc-minio
- toolsvc-minio.cdx-svc
- toolsvc-minio.cdx-svc.svc.cluster.local

Tool Orchestration Host Names:

- toolsvc-codedx-tool-orchestration
- toolsvc-codedx-tool-orchestration.cdx-svc
- toolsvc-codedx-tool-orchestration.cdx-svc.svc.cluster.local

The following sections will assume you have a toolsvc-minio.pem file and a toolsvc-minio.key file for MinIO, and a toolsvc-tool-orchestration.pem file and a toolsvc-tool-orchestration.key file for the Tool Orchestration service.

## Installing the Chart

Using this chart requires [Helm v3](https://docs.helm.sh/), a Kubernetes package manager. You can find instructions for installing Helm [here](https://helm.sh/docs/intro/install/).

## Registering the Code Dx Repository

Once Helm is installed, the Code Dx Charts repository must be registered for Helm to know about the chart. Run this command to register the Code Dx repository:

```bash
$ helm repo add codedx https://codedx.github.io/codedx-kubernetes
```

Test that it installed correctly by running:

```bash
$ helm install --generate-name codedx/codedx-tool-orchestration --dry-run
NAME: codedx-tool-orchestration-1576865171
metadata...
resources...
```

This command with `--dry-run` will simulate an install and show the Kubernetes resources that would be generated from the `codedx/codedx-tool-orchestration` chart. If it runs successfully, it will output a randomly-generated name for the installation and the resources that would have been deployed. Each deployment managed by Helm has a name that is referred to for later operations like upgrading and deleting.

### Your Installation Options File

We recommend keeping installation options in your own `toolsvc-values.yaml` file and using `helm upgrade -f toolsvc-values.yaml --reuse-values ...` to prevent accidental changes to the installation when a configuration property is forgotten or missed.

Create a blank `toolsvc-values.yaml` file that you will update in the following sections.

### Configure MinIO Admin account

Select a username and password for the MinIO Admin account that the Tool Orchestration service requires. Add the username and password you selected to your `toolsvc-values.yaml` file in the minio section.

Note: Do not use the examples listed below (4uMk%FU6m9u3 and igI@2R24%^er).

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
```

### Configure MinIO TLS

Create a Kubernetes secret to store the certificate and key file for your MinIO server. This section assumes that you completed the TLS Configuration section, and that you have a toolsvc-minio.pem file and toolsvc-minio.key file.

```
kubectl -n cdx-svc create secret generic cdx-toolsvc-minio-tls --from-file=toolsvc-minio.pem --from-file=toolsvc-minio.key
```

Append the following tls configuration to your `toolsvc-values.yaml` file.

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'
```

Store the MinIO certificate data in a k8s ConfigMap by running the following command.

```
kubectl -n cdx-svc create configmap cdx-toolsvc-minio-cert --from-file=toolsvc-minio.pem
```

Append the following minioTlsTrust configuration to your `toolsvc-values.yaml` file so that Tool Orchestration components will trust your MinIO server certificate.

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'  
```

### Configure Network policy

By default, the chart will apply network policies that restrict network access. This document configures a network policy that restricts network traffic between Code Dx and the Tool Orchestration service using the cdx-app namespace label you created above. Append the following networkPolicy configuration to your `toolsvc-values.yaml` file to restrict network access using that label.

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'

networkPolicy:
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: 'cdx-app'      
```

### Code Dx Connection

The Tool Orchestration service sends analysis results to Code Dx. You must specify a URL where Code Dx can be reached. We recommend using HTTPS for the connection between the Tool Orchestration service and Code Dx. Append your Code Dx URL for the codedxBaseUrl configuration to your `toolsvc-values.yaml` file (this document assumes a Code Dx k8s service URL of https://codedx-app-codedx.cdx-app.svc.cluster.local:9090/codedx).

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'

networkPolicy:
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: 'cdx-app'

codedxBaseUrl: 'https://codedx-app-codedx.cdx-app.svc.cluster.local:9090/codedx'
```

### Tool Orchestration API Key

An administrative key is required for some Tool Orchestration features. Select an API key and append it for the toolServiceApiKey configuration to your `toolsvc-values.yaml` file. Do not use the example value (5eb6fbe3-8126-452c-95e9-83faa87453d4) shown below.

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'

networkPolicy:
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: 'cdx-app'

codedxBaseUrl: 'https://codedx-app-codedx.cdx-app.svc.cluster.local:9090/codedx'

toolServiceApiKey: '5eb6fbe3-8126-452c-95e9-83faa87453d4'
```

### Tool Service TLS

Create a Kubernetes secret to store the certificate and key file for your Tool Orchestration service. This section assumes that you completed the TLS Configuration section, and that you have a toolsvc-tool-orchestration.pem file and toolsvc-tool-orchestration.key file.

```
kubectl -n cdx-svc create secret generic cdx-toolsvc-tool-orchestration-tls --from-file=toolsvc-tool-orchestration.pem --from-file=toolsvc-tool-orchestration.key
```

Add the following toolServiceTls configuration to your `toolsvc-values.yaml` file.

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'

networkPolicy:
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: 'cdx-app'

codedxBaseUrl: 'https://codedx-app-codedx.cdx-app.svc.cluster.local:9090/codedx'

toolServiceApiKey: '5eb6fbe3-8126-452c-95e9-83faa87453d4'
toolServiceTls:
  secret: 'cdx-toolsvc-tool-orchestration-tls'
  certFile: 'toolsvc-tool-orchestration.pem'
  keyFile: 'toolsvc-tool-orchestration.key'
```

### Grant Access to a Private Docker Registry

The Tool Orchestration service may require access to a private Docker registry, something that's necessary when using the Burp Suite automation as an example. Create a Kubernetes secret containing your Docker registry credentials using one of the two following options.

#### Create Registry Credential - Command Line Option

You can create a Kubernetes secret with your Docker registry credential from the command line by running the following command, replacing #server#, #username#, #password#, and #email# with your own values:

```
kubectl -n cdx-svc create secret docker-registry my-docker-registry --docker-server=#server# --docker-username=#username# --docker-password=#password# --docker-email=#email#
```

#### Create Registry Credential - YAML File Option

Alternatively, you can create a Kubernetes secret containing your Docker registry credentials from a YAML file. Your file will look similar to what follows, but you must specify your own content for #value# - refer to [Pull an Image from a Private Registry](https://kubernetes.io/docs/tasks/configure-pod-container/pull-image-private-registry/) for more details.

```
apiVersion: v1
metadata:
  name: my-docker-registry
data:
  .dockerconfigjson: #value#
kind: Secret
type: kubernetes.io/dockerconfigjson
```

Save your YAML in a file named my-docker-registry.yaml and create your Kubernetes secret with the following command.

```
kubectl create -n cdx-svc -f my-docker-registry.yaml
```

#### Registry Credential Config

Since you named your Kubernetes secret my-docker-registry, append the following imagePullSecretKey configuration to your `toolsvc-values.yaml` file.

```
minio:
  global:
    minio:
      accessKeyGlobal: '4uMk%FU6m9u3'
      secretKeyGlobal: 'igI@2R24%^er'
  tls:
    enabled: true
    certSecret: 'cdx-toolsvc-minio-tls'
    publicCrt: 'toolsvc-minio.pem'
    privateKey: 'toolsvc-minio.key'

minioTlsTrust:
  configMapName: 'cdx-toolsvc-minio-cert'
  configMapPublicCertKeyName: 'toolsvc-minio.pem'

networkPolicy:
  codedxSelectors:
  - namespaceSelector:
      matchLabels:
        name: 'cdx-app'

codedxBaseUrl: 'https://codedx-app-codedx.cdx-app.svc.cluster.local:9090/codedx'

toolServiceApiKey: '5eb6fbe3-8126-452c-95e9-83faa87453d4'
toolServiceTls:
  secret: 'cdx-toolsvc-tool-orchestration-tls'
  certFile: 'toolsvc-tool-orchestration.pem'
  keyFile: 'toolsvc-tool-orchestration.key'

imagePullSecretKey: 'my-docker-registry'
```

### Run Helm Install

After completing the sections above, you can now install the chart using your `toolsvc-values.yaml` file.

Note: The argo controller service account name is not based on release name, so multiple installs of argo to the same namespace will cause conflicts unless `argo.controller.serviceAccount` is assigned to a new value.

Run the following command to start the install, specifying the correct path to toolsvc-values.yaml if it's not in your current directory.

```
helm install toolsvc --namespace cdx-svc --values toolsvc-values.yaml codedx/codedx-tool-orchestration
```

Repeatedly issue the following command until all pods show a "Running" STATUS with a "1/1" READY value.

```
kubectl -n cdx-svc get pod
```

## Connect Code Dx to Tool Orchestration

With the Tool Orchestration components installed, you can now update your Code Dx Kubernetes deployment to use the tool service.

### Enable Tool Orchestration Service

Create a new file named `codedx-orchestration-values.yaml` file and add the following codedxProps configuration, replace the tws.apikey (5eb6fbe3-8126-452c-95e9-83faa87453d4) with the Tool Orchestration API key you selected.

```
codedxProps:
  extra:
  - type: values
    key: cdx-tool-orchestration
    values:
    - "tws.enabled = true"
    - "tws.service-url = https://toolsvc-codedx-tool-orchestration.cdx-svc.svc.cluster.local:3333"
    - "tws.api-key = 5eb6fbe3-8126-452c-95e9-83faa87453d4"
```

### Enable Network Policy

The Code Dx Helm chart supports a network policy for permitting access by the Tool Orchestration service. Use the following command to add a name=cdx-svc label to the cdx-svc namespace for this purpose.

```
kubectl label namespace cdx-svc name=cdx-svc
```

Append the following networkPolicy configuration to your `codedx-orchestration-values.yaml` file to permit the Tool Orchestration service to call Code Dx.

```
codedxProps:
  extra:
  - type: values
    key: cdx-tool-orchestration
    values:
    - "tws.enabled = true"
    - "tws.service-url = https://toolsvc-codedx-tool-orchestration.cdx-svc.svc.cluster.local:3333"
    - "tws.api-key = 5eb6fbe3-8126-452c-95e9-83faa87453d4"

networkPolicy:
  codedx:
    toolService: true
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: cdx-svc
```

### Trust Tool Orchestration Certificate

Acquire the cacerts file from your Code Dx application pod using the following command:

```
kubectl -n cdx-app cp CODE-DX-POD-NAME:/etc/ssl/certs/java/cacerts ./cacerts
```

Add the CA for the Tool Orchestration certificate if it is not already in cacerts. If you followed this document, you will add the k8s-ca.pem file with the following command.

```
keytool -import -trustcacerts -keystore cacerts -file .\k8s-ca.pem
```

Download the Code Dx Kubernetes chart with the following command.

```
helm pull codedx/codedx --untar
```

NOTE: Add the `--version` parameter if you did not install Code Dx using the latest Code Dx chart.

Copy your updated cacerts file to the codedx chart directory created by the previous command, and append the following cacertsFile configuration to your `codedx-orchestration-values.yaml` file.

```
codedxProps:
  extra:
  - type: values
    key: cdx-tool-orchestration
    values:
    - "tws.enabled = true"
    - "tws.service-url = https://toolsvc-codedx-tool-orchestration.cdx-svc.svc.cluster.local:3333"
    - "tws.api-key = 5eb6fbe3-8126-452c-95e9-83faa87453d4"

networkPolicy:
  codedx:
    toolService: true
    toolServiceSelectors:
    - namespaceSelector:
        matchLabels:
          name: cdx-svc

cacertsFile: 'cacerts'
```

### Upgrade Code Dx

Run the following command after replacing codedx-app with the Helm release name you used for your Code Dx install, path-to-code-dx-chart with the directory containing your Code Dx chart and cacerts file. Specify the correct path to your `codedx-orchestration-values.yaml` file if it's not in your chart directory.

```
helm upgrade --namespace cdx-app codedx-app --values codedx-orchestration-values.yaml --reuse-values path-to-code-dx-chart
```

### Enter License Key

You must license the Tool Orchestration software before using it with Code Dx. Upload a Code Dx license with the Tool Orchestration feature enabled by following the instructions [here](https://codedx.com/Documentation/InstallGuide.html#LicenseFile).
