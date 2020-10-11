
# Setup Script

Run the guided-setup.ps1 PowerShell Core script (in the root directory of this repository) to determine the correct setup.ps1 parameters for your Kubernetes cluster. The setup.ps1 script uses Helm to install and configure Code Dx and Tool Orchestration on a Kubernetes cluster.

## Script Parameters

This section describes the setup.ps1 script parameters, which you can specify by using the guided-setup.ps1 script.

| Parameter                                          | Description                                                | Default or (Example)                              |
|----------------------------------------------------|------------------------------------------------------------|---------------------------------------------------|
| `workDir`                                          | directory to store script-generated files                  | `$HOME/.k8s-codedx`                               |
| `kubeContextName`                                  | kubeconfig context entry to select at start up             | `eks` (example)                                   |
|                                                    |                                                            |                                                   |
| `clusterCertificateAuthorityCertPath`              | cert path for CA issuing certs via certificates.k8s.io API | `./aws-eks.pem` (example)                         |
| `codeDxDnsName`                                    | domain name for the Code Dx web application                | `www.codedx.io` (example)                         |
| `codeDxServicePortNumber`                          | HTTP port number for Code Dx k8s service                   | `9090`                                            |
| `codeDxTlsServicePortNumber`                       | HTTPS port number for Code Dx k8s service                  | `9443`                                            |
| `waitTimeSeconds`                                  | seconds to wait for install commands to complete           | `900`                                             |
|                                                    |                                                            |                                                   |
| `dbVolumeSizeGiB`                                  | volume size of the MariaDB master database                 | `32`                                              |
| `dbSlaveReplicaCount`                              | number of MariaDB slave instances                          | `1`                                               |
| `dbSlaveVolumeSizeGiB`                             | volume size of the MariaDB slave database                  | `32`                                              |
| `minioVolumeSizeGiB`                               | volume size for the MinIO storage application              | `32`                                              |
| `codeDxVolumeSizeGiB`                              | volume size for the Code Dx web application                | `32`                                              |
| `storageClassName`                                 | storage class name for persistance volumes                 | `gp2` (example)                                   |
|                                                    |                                                            |                                                   |
| `codeDxMemoryReservation`                          | memory request and limit for Code Dx                       | `16Gi` (example)                                  |
| `dbMasterMemoryReservation`                        | memory request and limit for the master database           | `16Gi` (example)                                  |
| `dbSlaveMemoryReservation`                         | memory request and limit for slave databases               | `16Gi` (example)                                  |
| `toolServiceMemoryReservation`                     | memory request and limit for the tool service              | `16Gi` (example)                                  |
| `minioMemoryReservation`                           | memory request and limit for MinIO                         | `16Gi` (example)                                  |
| `workflowMemoryReservation`                        | memory request and limit for workflow controller           | `16Gi` (example)                                  |
| `nginxMemoryReservation`                           | memory request and limit for nginx                         |                                                   |
|                                                    |                                                            |                                                   |
| `codeDxCPUReservation`                             | CPU request and limit for Code Dx                          | `2` (example)                                     |
| `dbMasterCPUReservation`                           | CPU request and limit for the master database              | `2` (example)                                     |
| `dbSlaveCPUReservation`                            | CPU request and limit for slave databases                  | `2` (example)                                     |
| `toolServiceCPUReservation`                        | CPU request and limit for the tool service                 | `2` (example)                                     |
| `minioCPUReservation`                              | CPU request and limit for MinIO                            | `2` (example)                                     |
| `workflowCPUReservation`                           | CPU request and limit for workflow controller              | `2` (example)                                     |
| `nginxCPUReservation`                              | CPU request and limit for nginx                            | `2` (example)                                     |
|                                                    |                                                            |                                                   |
| `codeDxEphemeralStorageReservation`                | storage request and limit for Code Dx                      | `2Gi`                                             |
| `dbMasterEphemeralStorageReservation`              | storage request and limit for the master database          | `2Gi` (example)                                   |
| `dbSlaveEphemeralStorageReservation`               | storage request and limit for slave databases              | `2Gi` (example)                                   |
| `toolServiceEphemeralStorageReservation`           | storage request and limit for the tool service             | `2Gi` (example)                                   |
| `minioEphemeralStorageReservation`                 | storage request and limit for MinIO                        | `2Gi` (example)                                   |
| `workflowEphemeralStorageReservation`              | storage request and limit for workflow controller          | `2Gi` (example)                                   |
| `nginxEphemeralStorageReservation`                 | storage request and limit for nginx                        | `2Gi` (example)                                   |
|                                                    |                                                            |                                                   |
| `imageCodeDxTomcat`                                | Code Dx Tomcat Docker image name                           | `latest version`                                  |
| `imageCodeDxTools`                                 | Code Dx Tools Docker image name                            | `latest version`                                  |
| `imageCodeDxToolsMono`                             | Code Dx Tools Mono Docker image name                       | `latest version`                                  |
| `imageNewAnalysis`                                 | Code Dx New Analysis Docker image name                     | `latest version`                                  |
| `imageSendResults`                                 | Code Dx Send Results Docker image name                     | `latest version`                                  |
| `imageSendErrorResults`                            | Code Dx Send Result Errors Docker image name               | `latest version`                                  |
| `imageToolService`                                 | Code Dx Tool Service Docker image name                     | `latest version`                                  |
| `imagePreDelete`                                   | Code Dx Tool Service pre-delete Docker image name          | `latest version`                                  |
|                                                    |                                                            |                                                   |
| `toolServiceReplicas`                              | number of tool service copies to run concurrently          | `3`                                               |
|                                                    |                                                            |                                                   |
| `skipTLS`                                          | whether Code Dx endpoints use TLS                          | `$false`                                          |
| `skipPSPs`                                         | whether to create pod security policies                    | `$false`                                          |
| `skipNetworkPolicies`                              | whether to skip creating network policies                  | `$false`                                          |
|                                                    |                                                            |                                                   |
| `skipNginxIngressControllerInstall`                | whether to install the NGINX ingress controller            | `$false`                                          |
| `nginxIngressControllerLoadBalancerIP`             | optional static IP for the NGINX ingress service           | `10.0.0.5` (example)                              |
|                                                    |                                                            |                                                   |
| `skipLetsEncryptCertManagerInstall`                | whether to install a Let's Encrypt Cert Manager            | `$false`                                          |
| `letsEncryptCertManagerRegistrationEmailAddress`   | email address for Let's Encrypt registration               | `me@codedx.com` (example)                         |
| `letsEncryptCertManagerClusterIssuer`              | cluster issuer (letsencrypt-staging or letsencrypt-prod)   | `letsencrypt-staging`                             |
| `letsEncryptCertManagerNamespace`                  | namespace for Cert Manager components                      | `cert-manager`                                    |
|                                                    |                                                            |                                                   |
| `serviceTypeCodeDx`                                | service type for the Code Dx service                       | `LoadBalancer`    (example)                       |
| `serviceAnnotationsCodeDx`                         | annotations for the Code Dx service                        | `@('key: value')` (example)                       |
|                                                    |                                                            |                                                   |
| `skipIngressEnabled`                               | whether to create the Code Dx ingress resource             | `$false`                                          |
| `skipIngressAssumesNginx`                          | whether the Code Dx ingress has an NGINX annotation        | `$true`                                           |
| `ingressAnnotationsCodeDx`                         | annotations for the Code Dx ingress                        | `@('key: value')` (example)                       |
|                                                    |                                                            |                                                   |
| `namespaceToolOrchestration`                       | namespace for Code Dx Tool Orchestration components        | `cdx-svc`                                         |
| `namespaceCodeDx`                                  | namespace for Code Dx application                          | `cdx-app`                                         |
| `nginxIngressControllerNamespace`                  | namespace for the NGINX Helm chart installation            | `nginx`                                           |
|                                                    |                                                            |                                                   |
| `releaseNameCodeDx`                                | name for the Code Dx Helm release                          | `codedx`                                          |
| `releaseNameToolOrchestration`                     | name for the Code Dx Tool Orchestration Helm release       | `codedx-tool-orchestration`                       |
|                                                    |                                                            |                                                   |
| `toolServiceApiKey`                                | the API key for the Code Dx Tool Orchestration service     | `[guid]::newguid()`                               |
|                                                    |                                                            |                                                   |
| `codedxAdminPwd`                                   | password for the Code Dx admin account                     | `HEPKmbRC4ANcd!` (example)                        |
| `minioAdminUsername`                               | username for the MinIO admin account                       | `admin`                                           |
| `minioAdminPwd`                                    | password for the MinIO admin account                       | `JGpS2t8UXj80o!` (example)                        |
| `mariadbRootPwd`                                   | password for the MariaDB root account                      | `ZjQLEg07BMNEf!` (example)                        |
| `mariadbReplicatorPwd`                             | password for the MariaDB replicator account                | `760nP8i6ZFzVS!` (example)                        |
|                                                    |                                                            |                                                   |
| `caCertsFilePath`                                  | file path for the Code Dx cacerts file                     | `./my-cacerts-file` (example)                     |
| `caCertsFilePwd`                                   | current password for the Code Dx cacerts file              | `changeit`                                        |
| `caCertsFileNewPwd`                                | new password to protect the Code Dx cacerts file           | `jcqBYa68G1usO!` (example)                        |
|                                                    |                                                            |                                                   |
| `extraCodeDxTrustedCaCertPaths`                    | trusted cert files to add to the Code Dx cacerts file      | `@('/cert.pem')` (example)                        |
|                                                    |                                                            |                                                   |
| `dockerImagePullSecretName`                        | k8s image pull secret name for a private Docker registry   | `my-registry`    (example)                        |
| `dockerRegistry`                                   | server name of private Docker registry                     | `myregistry.io`  (example)                        |
| `dockerRegistryUser`                               | username for private Docker registry                       | `myregistryuser` (example)                        |
| `dockerRegistryPwd`                                | password for private Docker registry username              | `R4dLYCfuda9ej!` (example)                        |
|                                                    |                                                            |                                                   |
| `codedxHelmRepo`                                   | Code Dx Helm repository                                    | `https://codedx.github.io/codedx-kubernetes`      |
|                                                    |                                                            |                                                   |
| `codedxGitRepo`                                    | Code Dx Kubernetes git repository                          | `https://github.com/codedx/codedx-kubernetes.git` |
| `codedxGitRepoBranch`                              | Code Dx Kubernetes git repository branch                   | `master`                                          |
|                                                    |                                                            |                                                   |
| `kubeApiTargetPort`                                | port number of the Kubernetes API                          | `443`                                             |
|                                                    |                                                            |                                                   |
| `extraCodeDxValuesPaths`                           | extra values.yaml file(s) for the Code Dx Helm chart       | `@('/file.yaml')` (example)                       |
| `extraToolOrchestrationValuesPaths`                | extra values.yaml file(s) for Tool Orchestration chart     | `@('/file.yaml')` (example)                       |
|                                                    |                                                            |                                                   |
| `skipDatabase`                                     | whether to skip installing MariaDB (use external database) | `$false`                                          |
| `externalDatabaseHost`                             | host name of external database                             | `mariadb.codedx.com` (example)                    |
| `externalDatabasePort`                             | port number for external database                          | 3306                                              |
| `externalDatabaseName`                             | existing database name in external database                | `codedx` (example)                                |
| `externalDatabaseUser`                             | existing username of external database user                | `codedx-user` (example)                           |
| `externalDatabasePwd`                              | password for external database user                        | `5Ed3&#Rutcdw` (example)                          |
| `externalDatabaseServerCert`                       | file path to CA issuing cert for external database         | `/tmp/cacert.pem` (example)                       |
| `externalDatabaseSkipTls`                          | whether to skip configuring one-way client auth            | `$false`                                          |
|                                                    |                                                            |                                                   |
| `skipToolOrchestration`                            | whether to skip installing the Tool Orchestration feature  | `$false`                                          |
|                                                    |                                                            |                                                   |
| `codeDxNodeSelector`                               | node selector for the Code Dx web application              | purpose=codedx (example)                          |
| `masterDatabaseNodeSelector`                       | node selector for the MariaDB master database pod          | purpose=codedx (example)                          |
| `subordinateDatabaseNodeSelector`                  | node selector for the MariaDB subordinate database pod(s)  | purpose=codedx (example)                          |
| `toolServiceNodeSelector`                          | node selector for the tool service pod(s)                  | purpose=codedx (example)                          |
| `minioNodeSelector`                                | node selector for the minio pod                            | purpose=codedx (example)                          |
| `workflowControllerNodeSelector`                   | node selector for the workflow controller pod              | purpose=codedx (example)                          |
|                                                    |                                                            |                                                   |
| `codeDxNoScheduleExecuteToleration`                | pod toleration for the Code Dx web application             | tag=web (example)                                 |
| `masterDatabaseNoScheduleExecuteToleration`        | pod toleration for the MariaDB master database pod         | tag=master (example)                              |
| `subordinateDatabaseNoScheduleExecuteToleration`   | pod toleration for the MariaDB subordinate database pod(s) | tag=subordinate (example)                         |
| `toolServiceNoScheduleExecuteToleration`           | pod toleration for the tool service pod(s)                 | tag=toolsvc (example)                             |
| `minioNoScheduleExecuteToleration`                 | pod toleration for the minio pod                           | tag=minio (example)                               |
| `workflowControllerNoScheduleExecuteToleration`    | pod toleration for the workflow controller pod             | tag=workflowcontroller (example)                  |
|                                                    |                                                            |                                                   |
| `useSaml`                                          | whether to use a SAML IdP                                  | false                                             |
| `samlAppName`                                      | application name previously registered with your SAML IdP  | codedxclient (example)                            |
| `samlIdentityProviderMetadataPath`                 | XML metadata file for your SAML IdP                        | idp-metadata.xml (example)                        |
| `samlKeystorePwd`                                  | password to secure SAML-related Java keystore              | `5Ed3&#Rutdcw` (example)                          |
| `samlPrivateKeyPwd`                                | password to secure private key stored in Java keystore     | `5Ed3&#Rutcwd` (example)                          |
|                                                    |                                                            |                                                   |
| `pauseAfterGitClone`                               | whether to pause (for debug purposes) after git clone      |                                                   |
|                                                    |                                                            |                                                   |
| `provisionNetworkPolicy`                           | script block for optional network policy provisioning      |                                                   |
| `provisionIngressController`                       | script block for optional ingress controller provisioning  |                                                   |
