
# Setup Script

The setup.ps1 PowerShell Core script uses Helm to install and configure Code Dx and Tool Orchestration on a Kubernetes cluster. The setup.ps1 script located here gets called indirectly by the setup.ps1 scripts in the provider-specific folders. See the README files under aws, azure, and minikube for more details.

## Script Parameters

This section describes the setup.ps1 script parameters.

>Note: Refer to the README files under aws, azure, and minikube for instructions on how to configure Code Dx for those environments.

| Parameter                                        | Description                                                    | Default                                         | Example          |
|--------------------------------------------------|----------------------------------------------------------------|-------------------------------------------------|------------------|
| workDir                                          | workDir specifies a directory to store script-generated files  | $HOME/.k8s-codedx                               |                  |
| kubeContextName                                  | name of the kubeconfig context entry to select at start up     |                                                 | eks              |
|                                                  |                                                                |                                                 |                  |
| clusterCertificateAuthorityCertPath              | path to your cluster's CA certificate file                     |                                                 | ./aws-eks.pem    |
| codeDxDnsName                                    | domain name for the Code Dx web application                    |                                                 | www.codedx.io    |
| codeDxServicePortNumber                          | HTTP port number for Code Dx k8s service                       | 9090                                            |                  |
| codeDxTlsServicePortNumber                       | HTTPS port number for Code Dx k8s service                      | 9443                                            | 443              |
| waitTimeSeconds                                  | seconds to wait for install commands to complete               | 900                                             |                  |
|                                                  |                                                                |                                                 |                  |
| dbVolumeSizeGiB                                  | size of the volume for the MariaDB master database             | 32                                              |                  |
| dbSlaveReplicaCount                              | number of MariaDB slave instances                              | 1                                               |                  |
| dbSlaveVolumeSizeGiB                             | size of the volume for each MariaDB slave database             | 32                                              |                  |
| minioVolumeSizeGiB                               | size of the volume for the MinIO storage application           | 32                                              |                  |
| codeDxVolumeSizeGiB                              | size of the volume for the Code Dx web application             | 32                                              |                  |
| storageClassName                                 | name of the storage class for persistance volumes              |                                                 |                  |
|                                                  |                                                                |                                                 |                  |
| codeDxMemoryReservation                          | memory resource request and limit for Code Dx                  |                                                 | 16Gi             |
| dbMasterMemoryReservation                        | memory resource request and limit for the master database      |                                                 | 16Gi             |
| dbSlaveMemoryReservation                         | memory resource request and limit for slave databases          |                                                 | 16Gi             |
| toolServiceMemoryReservation                     | memory resource request and limit for the tool service         |                                                 | 16Gi             |
| minioMemoryReservation                           | memory resource request and limit for MinIO                    |                                                 | 16Gi             |
| workflowMemoryReservation                        | memory resource request and limit for the workflow controller  |                                                 | 16Gi             |
| nginxMemoryReservation                           | memory resource request and limit for nginx                    |                                                 | 16Gi             |
|                                                  |                                                                |                                                 |                  |
| codeDxCPUReservation                             | CPU resource request and limit for Code Dx                     |                                                 | 2                |
| dbMasterCPUReservation                           | CPU resource request and limit for the master database         |                                                 | 2                |
| dbSlaveCPUReservation                            | CPU resource request and limit for slave MariaDB databases     |                                                 | 2                |
| toolServiceCPUReservation                        | CPU resource request and limit for the tool service            |                                                 | 2                |
| minioCPUReservation                              | CPU resource request and limit for MinIO                       |                                                 | 2                |
| workflowCPUReservation                           | CPU resource request and limit for the workflow controller     |                                                 | 2                |
| nginxCPUReservation                              | CPU resource request and limit for nginx                       |                                                 | 2                |
|                                                  |                                                                |                                                 |                  |
| codeDxEphemeralStorageReservation                | Ephemeral storage resource request for Code Dx                 | 2Gi                                             |                  |
| dbMasterEphemeralStorageReservation              | Ephemeral storage resource request for the master database     |                                                 | 2Gi              |
| dbSlaveEphemeralStorageReservation               | Ephemeral storage resource request for slave MariaDB databases |                                                 | 2Gi              |
| toolServiceEphemeralStorageReservation           | Ephemeral storage resource request for the tool service        |                                                 | 2Gi              |
| minioEphemeralStorageReservation                 | Ephemeral storage resource request for MinIO                   |                                                 | 2Gi              |
| workflowEphemeralStorageReservation              | Ephemeral storage resource request for the workflow controller |                                                 | 2Gi              |
| nginxEphemeralStorageReservation                 | Ephemeral storage resource request for nginx                   |                                                 | 2Gi              |
|                                                  |                                                                |                                                 |                  |
| imageCodeDxTomcat                                | name of the Code Dx Tomcat Docker image                        | latest version                                  |                  |
| imageCodeDxTools                                 | name of the Code Dx Tools Docker image                         | latest version                                  |                  |
| imageCodeDxToolsMono                             | name of the Code Dx Tools Mono Docker image                    | latest version                                  |                  |
| imageNewAnalysis                                 | name of the Code Dx New Analysis Docker image                  | latest version                                  |                  |
| imageSendResults                                 | name of the Code Dx Send Results Docker image                  | latest version                                  |                  |
| imageSendErrorResults                            | name of the Code Dx Send Result Errors Docker image            | latest version                                  |                  |
| imageToolService                                 | name of the Code Dx Tool Service Docker image                  | latest version                                  |                  |
| imagePreDelete                                   | name of the Code Dx Tool Service pre-delete Docker image       | latest version                                  |                  |
|                                                  |                                                                |                                                 |                  |
| toolServiceReplicas                              | number of tool service copies to run concurrently              | 3                                               |                  |
|                                                  |                                                                |                                                 |                  |
| useTLS                                           | whether Code Dx endpoints use TLS                              | $true                                           |                  |
| usePSPs                                          | whether to create pod security policies                        | $true                                           |                  |
|                                                  |                                                                |                                                 |                  |
| skipNetworkPolicies                              | whether to skip creating network policies                      | $false                                          |                  |
|                                                  |                                                                |                                                 |                  |
| nginxIngressControllerInstall                    | whether to install the NGINX ingress controller                | $true                                           |                  |
| nginxIngressControllerLoadBalancerIP             | optional static IP address for the NGINX ingress service       |  					                              | 10.0.0.5         |
|                                                  |                                                                |                                                 |                  |
| letsEncryptCertManagerInstall                    | whether to install a Let's Encrypt Cert Manager                | $true                                           |                  |
| letsEncryptCertManagerRegistrationEmailAddress   | email address for Let's Encrypt registration                   |                                                 | me@codedx.com    |
| letsEncryptCertManagerClusterIssuer              | cluster issuer name (letsencrypt-staging or letsencrypt-prod)  | letsencrypt-staging                             |                  |
| letsEncryptCertManagerNamespace                  | namespace for Cert Manager components                          | cert-manager                                    |                  |
|                                                  |                                                                |                                                 |                  |
| serviceTypeCodeDx                                | service type for the Code Dx service                           |                                                 | LoadBalancer     |
| serviceAnnotationsCodeDx                         | annotations for the Code Dx service                            |                                                 | @('key: value')  |
|                                                  |                                                                |                                                 |                  |
| ingressEnabled                                   | whether to create the Code Dx ingress resource                 | $true                                           |                  |
| ingressAssumesNginx                              | whether the Code Dx ingress resource adds an NGINX annotation  | $true                                           |                  |
| ingressAnnotationsCodeDx                         | annotations for the Code Dx ingress                            |                                                 | @('key: value')  |
|                                                  |                                                                |                                                 |                  |
| namespaceToolOrchestration                       | namespace for Code Dx Tool Orchestration components            | cdx-svc                                         |                  |
| namespaceCodeDx                                  | namespace for Code Dx application                              | cdx-app                                         |                  |
| namespaceIngressController                       | namespace for the NGINX Helm chart installation                | nginx                                           |                  |
|                                                  |                                                                |                                                 |                  |
| releaseNameCodeDx                                | name for the Code Dx Helm release                              | codedx                                          |                  |
| releaseNameToolOrchestration                     | name for the Code Dx Tool Orchestration Helm release           | codedx-tool-orchestration                       |                  |
|                                                  |                                                                |                                                 |                  |
| toolServiceApiKey                                | the API key for the Code Dx Tool Orchestration service         | [guid]::newguid()                               |                  |
|                                                  |                                                                |                                                 |                  |
| codedxAdminPwd                                   | password for the Code Dx admin account                         |                                                 | 2XHEPKmbRC4ANcd! |
| minioAdminUsername                               | username for the MinIO admin account                           | admin                                           |                  |
| minioAdminPwd                                    | password for the MinIO admin account                           |                                                 | 3FJGpS2t8UXj80o! |
| mariadbRootPwd                                   | password for the MariaDB root account                          |                                                 | eKZjQLEg07BMNEf! |
| mariadbReplicatorPwd                             | password for the MariaDB replicator account                    |                                                 | wn760nP8i6ZFzVS! |
|                                                  |                                                                |                                                 |                  |
| caCertsFilePwd                                   | current password for the Code Dx cacerts file                  | changeit                                        |                  |
| caCertsFileNewPwd                                | new password to protect the Code Dx cacerts file               |                                                 | W6jcqBYa68G1usO! |
|                                                  |                                                                |                                                 |                  |
| extraCodeDxChartFilesPaths                       | files to copy into the Code Dx chart folder at install time    |                                                 | @('/cacerts')    |
| extraCodeDxTrustedCaCertPaths                    | trusted certificate files to add to the Code Dx cacerts file   |                                                 | @('/cert.pem')   |
|                                                  |                                                                |                                                 |                  |
| dockerImagePullSecretName                        | k8s image pull secret name for a private Docker registry       |                                                 | my-registry      |
| dockerRegistry                                   | server name of private Docker registry                         |                                                 | myregistry.io    |
| dockerRegistryUser                               | username for private Docker registry                           |                                                 | myregistryuser   |
| dockerRegistryPwd                                | password for private Docker registry username                  |                                                 | 8ER4dLYCfuda9ej! |
|                                                  |                                                                |                                                 |                  |
| codedxHelmRepo                                   | Code Dx Helm repository                                        | https://codedx.github.io/codedx-kubernetes      |                  |
|                                                  |                                                                |                                                 |                  |
| codedxGitRepo                                    | Code Dx Kubernetes git repository                              | https://github.com/codedx/codedx-kubernetes.git |                  |
| codedxGitRepoBranch                              | Code Dx Kubernetes git repository branch                       | master                                          |                  |
|                                                  |                                                                |                                                 |                  |
| kubeApiTargetPort                                | port number of the Kubernetes API                              | 443                                             |                  |
|                                                  |                                                                |                                                 |                  |
| extraCodeDxValuesPaths                           | extra values.yaml file(s) for the Code Dx Helm chart           |                                                 | @('/file.yaml')  |
| extraToolOrchestrationValuesPaths                | extra values.yaml file(s) for Tool Orchestration Helm chart    |                                                 | @('/file.yaml')  |
|                                                  |                                                                |                                                 |                  |
| skipDatabase                                     | whether to skip installing MariaDB (use external database)     | $false                                          |                  |
| skipToolOrchestration                            | whether to skip installing the Tool Orchestration feature      | $false                                          |                  |
| addDefaultPodSecurityPolicyForAuthenticatedUsers | whether to install a default, privileged pod security policy   | $false                                          |                  |
|                                                  |                                                                |                                                 |                  |
| provisionNetworkPolicy                           | script block for any required network policy provisioning      |                                                 |                  |
| provisionIngressController                       | script block for any required ingress controller provisioning  |                                                 |                  |
