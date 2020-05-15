
# Setup Script

The setup.ps1 PowerShell Core script uses Helm to install and configure Code Dx and Tool Orchestration on a Kubernetes cluster. The setup.ps1 script located here gets called indirectly by the setup.ps1 scripts in the provider-specific folders. See the README files under aws, azure, and minikube for more details.

## Script Parameters

This section describes the setup.ps1 script parameters.

>Note: Refer to the README files under aws, azure, and minikube for instructions on how to configure Code Dx for those environments.

| Parameter | Description | Default | Example |
|---|---|---|---|
| workDir | workDir specifies a directory to store script-generated files | $HOME/.k8s-codedx | |
| kubeContextName | kubeContextName specifies the name of the kubeconfig context entry to select before starting the setup | |
| clusterCertificateAuthorityCertPath | clusterCertificateAuthorityCertPath specifies a path to your cluster's CA certificate file | | ./aws-eks.pem |
| codeDxDnsName | codeDxDnsName specifies the domain name for the Code Dx web application | | www.codedx.io |
| codeDxPortNumber | codeDxPortNumber specifies the port number bound to the Code Dx web application | 8443 | |
| waitTimeSeconds | waitTimeSeconds specifies the amount of time to wait for install commands to complete | 900 | |
| dbVolumeSizeGiB | dbVolumeSizeGiB specifies the size of the volume for the MariaDB database | 32 | |
| dbSlaveReplicaCount | dbSlaveReplicaCount specifies the number of MariaDB slave instances | 0 | |
| dbSlaveVolumeSizeGiB | dbSlaveVolumeSizeGiB specifies the size of the volume for each MariaDB slave instance | 32 | |
| minioVolumeSizeGiB | minioVolumeSizeGiB specifies the size of the volume for the MinIO storage application | 32 | |
| codeDxVolumeSizeGiB | codeDxVolumeSizeGiB specifies the size of the volume for the Code Dx web application | 32 | |
| storageClassName | storageClassName specifies the name of the storage class for persistance volumes | | |
| codeDxMemoryReservation | codeDxMemoryReservation specifies the memory resource request and limit for Code Dx | |
| dbMasterMemoryReservation | dbMasterMemoryReservation specifies the memory resource request and limit for the master MariaDB instance | |
| dbSlaveMemoryReservation | dbSlaveMemoryReservation specifies the memory resource request and limit for slave MariaDB instances | |
| toolServiceMemoryReservation | toolServiceMemoryReservation specifies the memory resource request and limit for the tool service  | |
| minioMemoryReservation | minioMemoryReservation specifies the memory resource request and limit for MinIO | |
| workflowMemoryReservation | workflowMemoryReservation specifies the memory resource request and limit for the workflow controller | |
| nginxMemoryReservation | nginxMemoryReservation specifies the memory resource request and limit for nginx | |
| codeDxCPUReservation | codeDxCPUReservation specifies the CPU resource request and limit for Code Dx | |
| dbMasterCPUReservation | dbMasterCPUReservation specifies the CPU resource request and limit for the master MariaDB instance | |
| dbSlaveCPUReservation | dbSlaveCPUReservation specifies the CPU resource request and limit for slave MariaDB instances | |
| toolServiceCPUReservation | toolServiceCPUReservation specifies the CPU resource request and limit for the tool service  | |
| minioCPUReservation | minioCPUReservation specifies the CPU resource request and limit for MinIO | |
| workflowCPUReservation | workflowCPUReservation specifies the CPU resource request and limit for the workflow controller | |
| nginxCPUReservation | nginxCPUReservation specifies the CPU resource request and limit for nginx | |
| imageCodeDxTomcat | imageCodeDxTomcat specifies the name of the Code Dx Docker image | codedx/codedx-tomcat:version |
| imageCodeDxTools | imageCodeDxTools specifies the name of the Code Dx Tools Docker image | codedx/codedx-tools:version | |
| imageCodeDxToolsMono | imageCodeDxToolsMono specifies the name of the Code Dx Tools Mono Docker image | codedx/codedx-toolsmono:version | |
| imageNewAnalysis | imageNewAnalysis specifies the name of the Code Dx New Analysis Docker image | codedx/codedx-newanalysis:version | |
| imageSendResults | imageSendResults specifies the name of the Code Dx Send Results Docker image | codedx/codedx-results:version | |
| imageSendErrorResults | imageSendErrorResults specifies the name of the Code Dx Send Result Errors Docker image | codedx/codedx-error-results:version | |
| imageToolService | imageToolService specifies the name of the Code Dx Tool Service Docker image | codedx/codedx-tool-service:version | |
| imagePreDelete | imagePreDelete specifies the name of the Code Dx Tool Service pre-delete Docker image | codedx/codedx-cleanup:version | |
| toolServiceReplicas | toolServiceReplicas specifies the number of tool service copies to run concurrently | 3 | |
| useTLS | useTLS specifies whether Code Dx endpoints use TLS | $true | |
| usePSPs | usePSPs specifies whether to create Code Dx pod security policies | $true | |
| skipNetworkPolicies | skipNetworkPolicies specifies whether to skip creating Code Dx network policies | $false | |
| ingressRegistrationEmailAddress | ingressRegistrationEmailAddress specifies the email address for the Let's Encrypt configuration | | |
| ingressLoadBalancerIP | ingressLoadBalancerIP specifies the static IP address for the nginx ingress service | | |
| ingressClusterIssuer | ingressClusterIssuer specifies the name of the Cert Manager cluster issuer | letsencrypt-staging | letsencrypt-staging or letsencrypt-prod |
| namespaceToolOrchestration | namespaceToolOrchestration specifies the namespace for the tool orchestration components | cdx-svc | |
| namespaceCodeDx | namespaceCodeDx specifies the namespace for the Code Dx application | cdx-app | |
| namespaceIngressController | namespaceIngressController specifies the namespace for the nginx Helm chart installation | nginx | |
| namespaceCertManager | namespaceCertManager specifies the namespace for the cert manager Helm chart installation | cert-manager | |
| releaseNameCodeDx | releaseNameCodeDx specifies the name for the Code Dx Helm release | codedx-app | |
| releaseNameToolOrchestration | releaseNameToolOrchestration specifies the name for the Code Dx Tool Orchestration Helm release | toolsvc-codedx-tool-orchestration | |
| toolServiceApiKey | toolServiceApiKey specifies the API key for the Code Dx Tool Orchestration service | [guid]::newguid() | |
| codedxAdminPwd | codedxAdminPwd specifies the password for the Code Dx admin account | | |
| minioAdminUsername | minioAdminUsername specifies the username for the MinIO admin account | admin | |
| minioAdminPwd | minioAdminPwd specifies the password for the MinIO admin account | | |
| mariadbRootPwd | mariadbRootPwd specifies the password for the MariaDB root account | | |
| mariadbReplicatorPwd | mariadbReplicatorPwd specifies the password for the MariaDB replicator account | | |
| caCertsFilePwd | caCertsFilePwd specifies the current password of the Code Dx cacerts file | changeit | |
| caCertsFileNewPwd | caCertsFileNewPwd specifies the new password to protect the Code Dx cacerts file | | |
| extraCodeDxChartFilesPaths | extraCodeDxChartFilesPaths specifies a list of files to copy into the Code Dx chart folder at chart install time | | |
| extraCodeDxTrustedCaCertPaths | extraCodeDxTrustedCaCertPaths specifies a list of certificate files of trusted CAs to import into the Code Dx cacerts file | | |
| dockerImagePullSecretName | dockerImagePullSecretName specifies the name of a Kubernetes image pull secret to create for a private Docker registry | | |
| dockerRegistry | dockerRegistry specifies the server value of a private Docker registry | | required when specifying dockerImagePullSecretName |
| dockerRegistryUsername | dockerRegistryUsername specifies a username for a private Docker registry | | required when specifying dockerImagePullSecretName |
| dockerRegistryPwd | dockerRegistryPwd specifies the password for a private Docker registry username | | required when specifying dockerImagePullSecretName |
| codedxHelmRepo | codedxHelmRepo specifies the URL of the Code Dx Helm repository | https://codedx.github.io/codedx-kubernetes | |
| codedxGitRepo | codedxGitRepo specifies the URL of the Code Dx Kubernetes git repository | https://github.com/codedx/codedx-kubernetes.git | |
| codedxGitRepoBranch | codedxGitRepoBranch specifies the branch to fetch from the Code Dx Kubernetes git repository | master | |
| kubeApiTargetPort | kubeApiTargetPort specifies the port of the Kubernetes API | 443 | |
| extraCodeDxValuesPaths | extraCodeDxValuesPaths specifies one or more extra values.yaml files for the Code Dx Helm chart | | |
| extraToolOrchestrationValuesPaths | extraToolOrchestrationValuesPaths specifies one or more extra values.yaml files for the Code Dx Tool Orchestration Helm chart | | |
| skipToolOrchestration | skipToolOrchestration specifies whether to skip installing the Tool Orchestration feature | $false | |
| provisionNetworkPolicy | provisionNetworkPolicy specifies a script block to call for any required network policy provisioning | | |
| provisionIngress | provisionIngress specifies a script block to call for any required ingress controller provisioning | | |
