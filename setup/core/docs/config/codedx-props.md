# Configure Code Dx Properties

Here are the steps to specify values for properties in the `codedx.props` file described in the [Code Dx Install Guide](https://documentation.blackduck.com/bundle/srm/page/install_guide/SRMConfiguration/config-files.html). There are two types of property values you may want to configure. Private property values are those with values that should be protected such as passwords, and they get stored in a Kubernetes Secret. Public property values are loaded from a Kubernetes ConfigMap.

## Proxy Server Example

The following steps will configure a [proxy server](https://documentation.blackduck.com/bundle/srm/page/install_guide/SRMConfiguration/proxy.html) for Code Dx using both public and private property values.

If you have not yet run the guided setup to determine the setup command(s) for deploying Code Dx on your Kubernetes cluster, do so now and end the guided setup by using one of the options to save your setup command to a file.

### Public Property Values

The steps in this section show you how to configure public property values by specifying the proxy.host and proxy.port values.

1) Create a file named `codedx-custom-props.yaml` and add the proxy.host, proxy.port, and proxy.nonProxyHosts property values as a new section named codedx-public-props (use spaces for the indents, tab characters will cause a failure at install-time):

```
codedxProps:
  extra:
  - key:  codedx-public-props
    type: values
    values:
    - "proxy.host = squid-restricted-http-proxy.squid"
    - "proxy.port = 3128"
    - "proxy.nonProxyHosts = codedx-tool-orchestration.cdx-svc.svc.cluster.local|codedx|localhost|*.internal.codedx.com"
```

>Note: Add non-proxy hosts as needed, separating each one with a pipe character. Code Dx deployments using Tool Orchestration must include \<tool-orchestration-release-name>.\<tool-orchestration-k8s-namespace>.svc.cluster.local. Code Dx deployments using the Triage Assistant must include <codedx-release-name>. The above configuration uses the default release names (codedx-tool-orchestration and codedx) and namespace (cdx-svc).

### Private Property Values

The steps in this section show you how to configure private property values by specifying the proxy.username and proxy.password values.

1) Create a file named `codedx-private-props` (no file extension) and add the proxy.username and proxy.password properties:

```
proxy.username = codedx
proxy.password = password
```

>Note: Use spaces for the indents shown above. Indenting with tab characters will cause a failure at install-time.

2) If necessary, pre-create the Kubernetes Code Dx namespace you specified during the guided setup. This will be the value of the `-namespaceCodeDx` setup.ps1 parameter. For example, to create the cdx-app namespace, run this command:

```
kubectl create ns cdx-app
```

3) Generate a Kubernetes Secret named `codedx-private-props` in the Code Dx namespace. For example, if your Code Dx namespace is cdx-app, run the following command (otherwise, replace cdx-app with your Code Dx namespace) from the directory containing codedx-private-props:

```
kubectl -n cdx-app create secret generic codedx-private-props --from-file=codedx-private-props
```

4) Edit the `codedx-custom-props.yaml` file you created in the previous section and add a reference to the codedx-private-props Kubernetes Secret you just created by appending an entry named codedx-private-props to the extra array (last three lines shown below):

```
codedxProps:
  extra:
  - key:  codedx-public-props
    type: values
    values:
    - "proxy.host = squid-restricted-http-proxy.squid"
    - "proxy.port = 3128"
  - key: codedx-private-props
    type: secret
    name: codedx-private-props
```

### Run Setup

1) Locate the run-setup.ps1 file generated by guided-setup.ps1 and make a copy named run-setup-custom.ps1. Edit run-setup-custom.ps1 by appending the following parameter to the setup.ps1 command line, specifying the path to your codedx-custom-props.yaml file:

```
 -extraCodeDxValuesPaths '/path/to/codedx-custom-props.yaml'
```

2) If you're using network policy, you must also add this parameter to your run-setup-custom.ps1 file, specifying the correct port for your proxy server.

```
 -proxyPort 3128
```

3) Follow the instructions provided at the end of guided-setup.ps1, but replace the run-setup.ps1 reference with run-setup-custom.ps1:

```
pwsh "/path/to/run-prereqs.ps1"
pwsh "/path/to/run-setup-custom.ps1"
```

>Note: You will have a run-prereqs.ps1 file if you selected the Save command with Kubernetes secret(s) option when saving your setup command.
