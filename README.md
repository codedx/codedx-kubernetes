# Code Dx Helm Chart

[![License](https://img.shields.io/badge/License-Apache%202.0-blue.svg)](https://opensource.org/licenses/Apache-2.0)

The Code Dx Helm chart creates an environment for development and test purposes (not suitable for production use).

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


