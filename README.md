# Code Dx Helm Chart

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

The Code Dx Helm chart creates an environment for development and test purposes. It may be used in production but has not been heavily tested.

## Installing the Chart

To install the chart with a `codedx` release name, run the following command from the incubator/codedx directory:

```
$ helm install --name codedx .
```

The chart contains a subchart reference to stable/mariadb version 5.2.3, which deploys MariaDB 10.1.37. 

## Uninstalling the Chart

To uninstall a chart with a `codedx` release name, run the following command (add `--purge` to permit the reuse of the `codedx` release name):

```
$ helm delete codedx
```

To remove the MariaDB persistent volume claims, run the following command:

```
$ kubectl delete pvc data-codedx-mariadb-master-0 data-codedx-mariadb-slave-0
```

# Configuration

The following table lists the configurable parameters of the Code Dx chart and their default values.

| Parameter                             | Description                                                                                                                                                                                        | Default                              |
|---------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------|
| codedxTomcatImage                     | Code Dx Tomcat image full name                                                                                                                                                                     | `codedx/codedx-tomcat:v3.5.3`        |
| codedxTomcatImagePullSecrets          | Pull secrets for Code Dx Tomcat image                                                                                                                                                              | `[]`                                 |
| codedxTomcatPort                      | Port for Code Dx Tomcat service                                                                                                                                                                    | `9090`                               |
| codedxAdminPassword                   | Password for Code Dx 'admin' account created at installation                                                                                                                                       | `wtKzR4F8o64A`                       |
| serviceAccount.create                 | Whether to create a ServiceAccount for Code Dx                                                                                                                                                     | `true`                               |
| serviceAccount.name                   | Name of the ServiceAccount for Code Dx                                                                                                                                                             |                                      |
| podSecurityPolicy.codedx.create       | Whether to create a PodSecurityPolicy for Code Dx pods                                                                                                                                             | `true`                               |
| podSecurityPolicy.codedx.name         | Name of the PodSecurityPolicy for Code Dx pods                                                                                                                                                     |                                      |
| podSecurityPolicy.codedx.bind         | Whether to bind the PodSecurityPolicy to Code Dx's ServiceAccount                                                                                                                                  | `true`                               |
| podSecurityPolicy.mariadb.create      | Whether to create a PodSecurityPolicy for MariaDB pods                                                                                                                                             | `true`                               |
| podSecurityPolicy.mariadb.name        | Name of the PodSecurityPolicy for MariaDB pods                                                                                                                                                     |                                      |
| podSecurityPolicy.mariadb.bind        | Whether to bind the PodSecurityPolicy to MariaDB's ServiceAccount                                                                                                                                  | `true`                               |
| networkPolicy.codedx.create           | Whether to create a NetworkPolicy for Code Dx                                                                                                                                                      | `true`                               |
| networkPolicy.codedx.ingressSelectors | [Additional Ingress selectors for the Code Dx NetworkPolicy against `codedxTomcatPort`](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.10/#networkpolicypeer-v1beta1-extensions) | `[]`                                 |
| networkPolicy.mariadb.master.create   | Whether to create a NetworkPolicy for the MariaDB Master                                                                                                                                           | `true`                               |
| networkPolicy.mariadb.slave.create    | Whether to create a NetworkPolicy for the MariaDB Slave                                                                                                                                            | `true`                               |
| persistence.storageClass              | Explicit storage class for Code Dx's appdata volume claim                                                                                                                                          | `""`                                 |
| persistence.accessMode                | Access mode for Code Dx's appdata volume claim                                                                                                                                                     | `ReadWriteOnce`                      |
| persistence.size                      | Size of Code Dx's appdata volume claim                                                                                                                                                             | `100Mi`                              |
| persistence.existingClaim             | The name of an existing volume claim to use for Code Dx's appdata                                                                                                                                  |                                      |
| ingress.enabled                       | Whether to create an Ingress resource for Code Dx                                                                                                                                                  | `false`                              |
| ingress.annotations                   | Additional annotations for a generated Code Dx Ingress resource                                                                                                                                    | NGINX proxy read-timeout + body-size |
| ingress.hosts                         | The list of Code Dx hosts to generate Ingress resources for                                                                                                                                        | `[sample]`                           |
| ingress.hosts[i].name                 | The FQDN of a Code Dx host                                                                                                                                                                         |                                      |
| ingress.hosts[i].tls                  | Whether to add HTTPS/TLS properties to the generated Ingress resource                                                                                                                              |                                      |
| ingress.hosts[i].tlsSecret            | The name of the TLS secret containing corresponding key and cert                                                                                                                                   |                                      |
| ingress.secrets                       | List of secrets to generate for use in TLS                                                                                                                                                         | `[]`                                 |
| ingress.secrets[i].name               | Name of the secret to be created                                                                                                                                                                   |                                      |
| ingress.secrets[i].key                | Base64-encoded encryption key                                                                                                                                                                      |                                      |
| ingress.secrets[i].certificate        | Base64-encoded encryption certificate                                                                                                                                                              |                                      |
| serviceType                           | Service type for Code Dx                                                                                                                                                                           | Based on Ingress config              |
| codedxProps.file                      | Location of a Code Dx `props` file for configuration                                                                                                                                               | `codedx.props`                       |
| codedxProps.configMap                 | Name of the ConfigMap that will store the Code Dx `props` file                                                                                                                                     |                                      |
| codedxProps.annotations               | Extra annotations attached to a generated codedx `props` ConfigMap                                                                                                                                 | `{}`                                 |
| codedxProps.dbconnection.createSecret | Whether to create a secret containing MariaDB creds                                                                                                                                                | `true`                               |
| codedxProps.dbconnection.secretName   | Name of the secret containing MariaDB creds                                                                                                                                                        |                                      |
| codedxProps.dbconnection.annotations  | Extra annotations attached to a generated MariaDB secret                                                                                                                                           | `{}`                                 |
| codedxProps.extra                     | List of extra secrets containing Code Dx props to be loaded                                                                                                                                        | `[]`                                 |
| codedxProps.extra[i].secretName       | Name of the secret to be loaded and mounted                                                                                                                                                        |                                      |
| codedxProps.extra[i].key              | Name of the key within the secret that contains Code Dx props text                                                                                                                                 |                                      |
| license.file                          | Location of a license for Code Dx to use during installation                                                                                                                                       |                                      |
| license.secret                        | Name of the secret that will store the Code Dx license                                                                                                                                             |                                      |
| license.annotations                   | Extra annotations attached to a Code Dx License secret                                                                                                                                             |                                      |
| loggingConfigFile                     | Location of a `logback.xml` file to customize Code Dx logging                                                                                                                                      |                                      |
| resources                             | Defines resource requests and limits for Code Dx                                                                                                                                                   |                                      |
| mariadb.rootUser.password             | Password for the MariaDB root user                                                                                                                                                                 | `5jqJL2b8hqn3`                       |
| mariadb.replication.password          | Password for the MariaDB replication server                                                                                                                                                        | `11uAQKLgv4JM`                       |
| mariadb.serviceAccount.create         | Whether to create a ServiceAccount for MariaDB                                                                                                                                                     | `true`                               |
| mariadb.serviceAccount.name           | Name of the ServiceAccount used by MariaDB                                                                                                                                                         |                                      |
| mariadb.*                             | [Extra MariaDB props found in its own chart](https://github.com/helm/charts/blob/master/stable/mariadb/README.md#configuration)                                                                    |                                      |

# Replication/Scalability

Code Dx does not officially support horizontal scaling. Attempting to use more than one replica for the Code Dx deployment can lead to bugs while using Code Dx, and possibly corruption of your database. Work is being done within Code Dx to better support this.

# Persistence

# Upgrading Code Dx

The Code Dx deployment should be using a `Replicate` strategy, to ensure that no more than one instance of Code Dx is operating against a database at any given time. This is particularly important during upgrades of the Code Dx image. If a database schema update occurs while more than once instance of Code Dx is running against that database, it will lead to errors, data loss, and possibly corruption of the database.

This does mean that zero-downtime updates are not currently possible with Code Dx. Research is being done to better support this.