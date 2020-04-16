
# Code Dx

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

[Code Dx](https://codedx.com/) is an automated application vulnerability management tool that makes all of your testing tools work together to provide one set of correlated results, then helps you prioritize and manage vulnerabilities — integrating with your application lifecycle management tools so your security and development teams work together for faster remediation.

The Code Dx Helm chart creates Kubernetes resources for a secure, production-ready Code Dx deployment and environment. To make the most of this, check that Network Policies and Pod Security Policies are enabled and enforced on your cluster.

>Note: This chart is compatible with a cluster running Kubernetes v1.14.

**This repository contains various in-depth guides in the [docs](docs) folder, outlined below.**

- [Code Dx Config](docs/codedx-config.md)
- [Code Dx Licensing](docs/codedx-licensing.md)
- [Ingress](docs/ingress.md)
- [Installation Guide](docs/installation-walkthrough.md)
- [Code Dx Native HTTPS](docs/codedx-https.md)
- [Upgrading Code Dx](docs/upgrading.md)

**Sample installation values can be found [here.](sample-values)**

## TL;DR

Run the following commands after replacing `<root-password>` and `<replication-password>` with your MariaDB root and replication passwords.

```
$ helm repo add codedx https://codedx.github.io/codedx-kubernetes
$ helm install codedx codedx/codedx --set mariadb.rootUser.password=<root-password> --set mariadb.replication.password=<replication-password>

OR

$ git clone https://github.com/codedx/codedx-kubernetes.git
$ cd codedx-kubernetes/codedx
$ helm dependency update
$ helm install codedx . --set mariadb.rootUser.password=<root-password> --set mariadb.replication.password=<replication-password>
```

We recommend keeping any extra installation options in your own `values.yaml` file and using `helm install/upgrade ... -f my-values.yaml`, to prevent accidental changes to the installation when a configuration property is forgotten or missed. Check out the [example YAML files](sample-values) for common use-cases.

## Prerequisite Details

- Kubernetes 1.8+
- Code Dx license ([purchase](https://codedx.com/purchase-application/) or [request a free trial](https://codedx.com/free-trial/))

## Chart Details

This chart will:

- Deploy a Code Dx instance
- Deploy the MariaDB chart with master and slaves
- Create service accounts, PodSecurityPolicies, and NetworkPolicies
- Create Ingress resources as necessary
- Create secrets for your Code Dx license, DB credentials, and default Code Dx Admin credentials

![Kubernetes Deployment Diagram](res/CodeDxK8s.png)

## Installing the Chart

Using this chart requires [Helm v3](https://docs.helm.sh/), a Kubernetes package manager. You can find instructions for installing Helm [here](https://helm.sh/docs/intro/install/).

This chart contains a reference to stable/mariadb chart version 5.5.0, and deploys MariaDB 10.3.22. (Note that "chart version" does not correspond to "app version".)

You can use this chart by either registering the Code Dx Helm Repository with `helm repo add` (described above) or by cloning the repository locally.

- Installation using the helm repository helps keep you up to date and doesn't require manually maintaining a copy of the chart
- Installation from a cloned copy of the chart can be helpful with troubleshooting and allows you to directly use files during configuration, instead of needing to store additional files beforehand (eg cacerts, license, etc.)

After installation, you'll be given commands to retrieve the Code Dx admin credentials that were generated. Use `kubectl get pods --watch` to check the status of the Code Dx installation. **Change the Code Dx admin password once installation is complete.** The secret used to get the admin credentials are only used for the first installation of Code Dx, and can change automatically when using `helm upgrade`. After installation and changing the admin password, the secret can be ignored entirely.

A complete installation guide can be found [here.](docs/installation-walkthrough.md)

**Before installing, you should first read the recommendations below.**

### Installation Recommendations

#### values.yaml
We recommend placing any configuration changes in a custom `values.yaml` and using the `-f` option to specify your values file with each call to `helm upgrade`. Otherwise, remember to use the `--reuse-values` when running `helm upgrade` so that you do not lose your changes during an upgrade.

**Some sample files are available in the [sample-values](sample-values) folder.**

#### MariaDB
When installing the chart in a public-facing environment, be sure to change the passwords for MariaDB Admin and MariaDB Replication. These passwords are not randomly generated and are nontrivial to change after installation. These should be assigned using a `values.yaml` file, either as plaintext, or preferably, in pre-defined secrets. An example of using predefined secrets can be found [here.](sample-values/values-secure-data.yaml)

```
$ helm install codedx codedx/codedx --set mariadb.rootUser.password=X --set mariadb.replication.password=Y
```

#### Network Policies and PSPs
It's recommended to leave PodSecurityPolicies and NetworkPolicies enabled for security. Note that controllers need to be available on the cluster to enforce these policies.

#### Volume Sizes
The default volume sizes for Code Dx and MariaDB are `32Gi` - `96Gi` total for the chart, by default. (One volume for Code Dx, one for MariaDB Master, and one for MariaDB Slave.) `32Gi` is not the minimum disk size - the chart can run with a `100Mi` volume for Code Dx and `1Gi` volumes for MariaDB. However, this will quickly fill up and can cause maintenance headaches. Keep in mind that source code, binaries, and scan results will be uploaded to and stored by Code Dx. The size of these files, frequency of scanning, and number of projects should be considered when determining an initial volume size. Expect MariaDB disk usage to be approximately equivalent to Code Dx.

**Depending on the projects being scanned, the default size may not be sufficient. Be sure to specify an appropriate claim size when installing Code Dx.**

#### Replication/Scalability

Code Dx does not officially support horizontal scaling. Attempting to use more than one replica for the Code Dx deployment can lead to bugs while using Code Dx, and possibly corruption of your database. Work is being done within Code Dx to better support this.

#### Providing Data Files

This chart contains options for handling various customized files for Code Dx, referred to as _Local File Options_. This includes `codedx.props`, `cacerts`, license files, and logging configuration files. These local file options are provided but will only work when installing the chart from source with `helm install codedx .`; if using the helm chart repository `helm install codedx codedx/codedx`, these options are effectively disabled.

When using the direct source code with a local file option, the file should be stored _inside the chart folder_ and file path values are relative to the chart folder. If the chart has been cloned to `/codedx-kubernetes/codedx`, new files should be placed in `/codedx-kubernetes/codedx`.

When using the packaged chart, local files can instead be provided through the `extraMounts` option. Create a ConfigMap or Secret manually and store your file's contents in it, then use the `extraMounts` option for Code Dx to use it. Files provided this way must be manually assigned a path to mount to, unlike the local file options which automatically provide the path. To find the right path for your file, look for the associated local file option in the chart's default `values.yaml` file. Each value has comments describing its use, and local file options will also include the location of the mount point in their comments.

## Uninstalling the Chart

To uninstall a chart with a `codedx` release name, run the following command:

```
$ helm uninstall codedx
```

To remove the MariaDB persistent volume claims, run the following command:

```
$ kubectl delete pvc data-codedx-mariadb-master-0 data-codedx-mariadb-slave-0
```

## Configuration

The following table lists the configurable parameters of the Code Dx chart and their default values.

Any values that require locally cloning the chart will be labeled with _"LFV"_ ("Local File Value") in their description.

| Parameter                               | Description                                                                                                                                                                                        | Default                              |
|-----------------------------------------|----------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------------|
| `codedxTomcatImage`                     | Code Dx Tomcat image full name                                                                                                                                                                     | `codedx/codedx-tomcat:v5.0.1`        |
| `codedxTomcatImagePullPolicy`           | Pull policy for the Code Dx Tomcat image                                                                                                                                                           | `IfNotPresent`                       |
| `codedxTomcatImagePullSecrets`          | Pull secrets for Code Dx Tomcat image                                                                                                                                                              | `[]`                                 |
| `codedxTomcatImagePullSecrets[i].name`  | Name of a secret to use for pulling the Code Dx Tomcat image                                                                                                                                       |                                      |
| `codedxTomcatPort`                      | Port for Code Dx Tomcat service                                                                                                                                                                    | `9090`                               |
| `codedxTlsTomcatPort`                   | Port for Code Dx Tomcat service when HTTPS/TLS is enabled                                                                                                                                          | `9090`                               |
| `codedxJavaOpts`                        | Extra options passed to Tomcat JVM                                                                                                                                                                 | `""`                                 |
| `codedxAdminPassword`                   | Password for Code Dx 'admin' account created at installation (random if empty)                                                                                                                     | `""`                                 |
| `cacertsFile`                           | _(LFV)_ Path to a custom _cacerts_ file for Code Dx                                                                                                                                                | `""`                                 |
| `serviceAccount.create`                 | Whether to create a ServiceAccount for Code Dx                                                                                                                                                     | `true`                               |
| `serviceAccount.name`                   | Name of the ServiceAccount for Code Dx                                                                                                                                                             |                                      |
| `podSecurityPolicy.codedx.create`       | Whether to create a PodSecurityPolicy for Code Dx pods                                                                                                                                             | `true`                               |
| `podSecurityPolicy.codedx.name`         | Name of the PodSecurityPolicy for Code Dx pods                                                                                                                                                     |                                      |
| `podSecurityPolicy.codedx.bind`         | Whether to bind the PodSecurityPolicy to Code Dx's ServiceAccount                                                                                                                                  | `true`                               |
| `podSecurityPolicy.mariadb.create`      | Whether to create a PodSecurityPolicy for MariaDB pods                                                                                                                                             | `true`                               |
| `podSecurityPolicy.mariadb.name`        | Name of the PodSecurityPolicy for MariaDB pods                                                                                                                                                     |                                      |
| `podSecurityPolicy.mariadb.bind`        | Whether to bind the PodSecurityPolicy to MariaDB's ServiceAccount                                                                                                                                  | `true`                               |
| `networkPolicy.codedx.create`           | Whether to create a NetworkPolicy for Code Dx                                                                                                                                                      | `true`                               |
| `networkPolicy.codedx.ldap`             | Whether to include a rule for allowing LDAP egress (port 389)                                                                                                                                      | `false`                              |
| `networkPolicy.codedx.ldaps`            | Whether to include a rule for allowing LDAPS egress (ports 636, 3269)                                                                                                                              | `false`                              |
| `networkPolicy.codedx.http`             | Whether to include a rule for allowing HTTP egress (port 80)                                                                                                                                       | `false`                              |
| `networkPolicy.codedx.https`            | Whether to include a rule for allowing HTTPS egress (port 443)                                                                                                                                     | `false`                              |
| `networkPolicy.codedx.dependencyCheck`  | Convenience property - if `true`, is the same as setting `http` and `https` values to `true` to allow Dependency-Check database updates                                                            | `true`                               |
| `networkPolicy.codedx.toolService`      | Whether to include a rule for allowing HTTP/S egress and ingress for communicating with a Tool Service (port 3333)                                                                                 | `false`                              |
| `networkPolicy.codedx.toolServiceSelectors`| [Selectors for the network policy allowing egress to a tool service](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.10/#networkpolicypeer-v1beta1-extensions)                 | `false`                              |
| `networkPolicy.codedx.ingressSelectors` | [Additional Ingress selectors for the Code Dx NetworkPolicy against `codedxTomcatPort`](https://kubernetes.io/docs/reference/generated/kubernetes-api/v1.10/#networkpolicypeer-v1beta1-extensions) | `[]`                                 |
| `networkPolicy.mariadb.master.create`   | Whether to create a NetworkPolicy for the MariaDB Master                                                                                                                                           | `true`                               |
| `networkPolicy.mariadb.slave.create`    | Whether to create a NetworkPolicy for the MariaDB Slave                                                                                                                                            | `true`                               |
| `persistence.storageClass`              | Explicit storage class for Code Dx's appdata volume claim                                                                                                                                          | `""`                                 |
| `persistence.accessMode`                | Access mode for Code Dx's appdata volume claim                                                                                                                                                     | `ReadWriteOnce`                      |
| `persistence.size`                      | Size of Code Dx's appdata volume claim                                                                                                                                                             | `32Gi`                               |
| `persistence.existingClaim`             | The name of an existing volume claim to use for Code Dx's appdata                                                                                                                                  |                                      |
| `ingress.enabled`                       | Whether to create an Ingress resource for Code Dx                                                                                                                                                  | `false`                              |
| `ingress.annotations`                   | Additional annotations for a generated Code Dx Ingress resource                                                                                                                                    | NGINX proxy read-timeout + body-size |
| `ingress.assumeNginxIngressController`  | Whether to include an NGINX-specific TLS annotation when `codedxTls` is configured                                                                                                                 | `true`                               |
| `ingress.hosts`                         | The list of Code Dx hosts to generate Ingress resources for                                                                                                                                        | `[sample]`                           |
| `ingress.hosts[i].name`                 | The FQDN of a Code Dx host                                                                                                                                                                         |                                      |
| `ingress.hosts[i].tls`                  | Whether to add HTTPS/TLS properties to the generated Ingress resource                                                                                                                              |                                      |
| `ingress.hosts[i].tlsSecret`            | The name of the TLS secret containing corresponding key and cert                                                                                                                                   |                                      |
| `ingress.secrets`                       | List of secrets to generate for use in TLS                                                                                                                                                         | `[]`                                 |
| `ingress.secrets[i].name`               | Name of the secret to be created                                                                                                                                                                   |                                      |
| `ingress.secrets[i].key`                | Base64-encoded encryption key                                                                                                                                                                      |                                      |
| `ingress.secrets[i].keyFile`            | _(LFV)_ Path to encryption key file (ignored if `key` is specified)                                                                                                                                |                                      |
| `ingress.secrets[i].certificate`        | Base64-encoded encryption certificate                                                                                                                                                              |                                      |
| `ingress.secrets[i].certificateFile`    | _(LFV)_ Path to encryption certificate file (ignored if `certificate` is specified)                                                                                                                |                                      |
| `serviceType`                           | Service type for Code Dx                                                                                                                                                                           | Based on Ingress config              |
| `codedxProps.file`                      | _(LFV)_ Location of a Code Dx `props` file for configuration                                                                                                                                       | `codedx.props`                       |
| `codedxProps.configMap`                 | Name of the ConfigMap that will store the Code Dx `props` file                                                                                                                                     |                                      |
| `codedxProps.annotations`               | Extra annotations attached to a generated codedx `props` ConfigMap                                                                                                                                 | `{}`                                 |
| `codedxProps.dbconnection.createSecret` | Whether to create a secret containing MariaDB creds                                                                                                                                                | `true`                               |
| `codedxProps.dbconnection.secretName`   | Name of the secret containing MariaDB creds                                                                                                                                                        |                                      |
| `codedxProps.dbconnection.annotations`  | Extra annotations attached to a generated MariaDB secret                                                                                                                                           | `{}`                                 |
| `codedxProps.extra`                     | List of extra secrets containing Code Dx props to be loaded                                                                                                                                        | `[]`                                 |
| `codedxProps.extra[i].secretName`       | Name of the secret to be loaded and mounted                                                                                                                                                        |                                      |
| `codedxProps.extra[i].key`              | Name of the key within the secret that contains Code Dx props text                                                                                                                                 |                                      |
| `license.file`                          | _(LFV)_ Location of a license for Code Dx to use during installation (the license file must not have a .lic file extension)                                                                        |                                      |
| `license.secret`                        | Name of the secret that will store the Code Dx license                                                                                                                                             |                                      |
| `license.annotations`                   | Extra annotations attached to a Code Dx License secret                                                                                                                                             |                                      |
| `loggingConfigFile`                     | _(LFV)_ Location of a `logback.xml` file to customize Code Dx logging                                                                                                                              |                                      |
| `samlIdpXmlFile`                        | _(LFV)_ Name of the XML file containing SAML IdP information.                                                                                                                                      |                                      |
| `extraMounts`                           | List of additional mounts to use                                                                                                                                                                   | `[]`                                 |
| `resources`                             | Defines [resource requests and limits](https://kubernetes.io/docs/concepts/configuration/manage-compute-resources-container/) for Code Dx                                                          |                                      |
| `codedxTls.enabled`                     | Whether to enable HTTPS access                                                                                                                                                                     | `false`                              |
| `mariadb.enabled`                       | Whether to install the MariaDB Helm chart                                                                                                                                                          | `true`                               |
| `mariadb.rootUser.password`             | Password for the MariaDB root user                                                                                                                                                                 | `5jqJL2b8hqn3`                       |
| `mariadb.replication.password`          | Password for the MariaDB replication server                                                                                                                                                        | `11uAQKLgv4JM`                       |
| `mariadb.serviceAccount.create`         | Whether to create a ServiceAccount for MariaDB                                                                                                                                                     | `true`                               |
| `mariadb.serviceAccount.name`           | Name of the ServiceAccount used by MariaDB                                                                                                                                                         |                                      |
| `mariadb.master.persistence.size`       | Persistent volume size for the MariaDB master database                                                                                                                                             | `32Gi`                               |
| `mariadb.slave.persistence.size`        | Persistent volume size for the MariaDB slave (replication) database                                                                                                                                | `32Gi`                               |
| `mariadb.*`                             | [Extra MariaDB props found in its own chart](https://github.com/helm/charts/blob/master/stable/mariadb/README.md#configuration)                                                                    |                                      |
