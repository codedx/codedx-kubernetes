# GitOps Toolkit (GitHub Configuration)

This document describes how to configure a GitHub repository named codedx-gitops for use with the GitOps Toolkit and Bitnami's Sealed Secrets.

The configuration in the git repository will manage a Kubernetes cluster referred to as the \"demo\" cluster where a Code Dx deployment can be managed using GitOps. Instructions refer to a fictitious GitHub repository at https://github.com/codedx/codedx-gitops and a made-up \"codedx\" kubectl context. To follow along with the instructions, replace the following content:

- replace the demo directory name with a directory name that represents your cluster
- replace the codedx-gitops GitHub repository with the location of your GitHub repository
- replace the codedx kubectl context with the context for your cluster

## One-Time Setup Steps

Here are the one-time steps required to bootstrap the demo cluster:

### Prerequisites:

1) Clone the GitHub repository (e.g., https://github.com/codedx/codedx-gitops), change directory to the repository root (codedx-gitops), and create the demo directory.

```
git clone https://github.com/codedx/codedx-gitops
cd codedx-gitops
mkdir demo
```

>Note 1: Replace the codedx-gitops GitHub repository with the location of your GitHub repository.

>Note 2: Replace the demo directory with a directory name that represents your cluster.

2) If using TLS, upload the public key file for the demo cluster's Certificate API. This is the ca.crt file generated when you run the [check-csr-legacy-unknown.ps1](https://github.com/codedx/codedx-kubernetes/blob/master/admin/checks/check-csr-legacy-unknown.ps1)script. 

```
cd codedx-gitops/demo
cp /path/to/ca.crt .
```

>Note 1: Skip this step if you're not using the Code Dx TLS deployment option.

>Note 2: Replace the repository name with your GitHub repository name.

>Note 3: Replace the demo directory with a directory name that represents your cluster.

### Steps:

1) Switch to the codedx context:

```
kubectl config use-context codedx
```

>Note: Replace the codedx kubectl context with the context for your cluster.

2) Generate a GitHub Personal Access Token for a user with all GitHub 'repo' permissions. Store the token in the GITHUB_TOKEN environment variable:

```
export GITHUB_TOKEN=TOKEN
```

3) Download the flux CLI tool and verify prerequisites:

```
flux check --pre
```

4) Bootstrap the flux components:

```
flux bootstrap github --owner=codedx --repository=codedx-gitops --branch=master --path=./demo
```

>Note 1: You may require an alternate flux bootstrap command based on your GitHub repository. Refer to the [GitOps Toolkit instructions](https://fluxcd.io/docs/installation/) for more details.

>Note 2: Replace the GitHub repository details with your GitHub repository information.

>Note 3: Replace the demo directory with a directory name that represents your cluster.

>Note 4: The above command will create a demo/flux-system directory in your GitHub repository.

5) Change directory to the root of the codedx-gitops git repo and pull latest:

```
cd ~/git/codedx-gitops
git pull --rebase
```

>Note: Replace the repository name with the name of your GitHub repository.

6) Create directories for the sealed-secrets release:

```
mkdir -p ./demo/Releases/SealedSecrets/HelmRepository
mkdir -p ./demo/Releases/SealedSecrets/HelmRelease
```

>Note: Replace the demo directory with a directory name that represents your cluster.

7) Generate the sealed-secrets HelmRepository resource:

```
flux create source helm sealed-secrets --interval=1h --url=https://bitnami-labs.github.io/sealed-secrets --export > ./demo/Releases/SealedSecrets/HelmRepository/helmrepository-flux-system-sealed-secrets.yaml
```
>Note: Replace the demo directory with a directory name that represents your cluster.

8) Generate the sealed-secrets HelmRelease resource:

```
flux create helmrelease sealed-secrets --interval=1h --release-name=sealed-secrets --target-namespace=flux-system --source=HelmRepository/sealed-secrets --chart=sealed-secrets --chart-version=">=1.15.0-0" --crds=CreateReplace --export > ./demo/Releases/SealedSecrets/HelmRelease/helmrelease-flux-system-sealed-secrets.yaml
```
>Note: Replace the demo directory with a directory name that represents your cluster.

9) Commit the demo/Releases/SealedSecrets files.

>Note: Replace the demo directory with a directory name that represents your cluster.

10) Monitor the sealed-secrets deployment log (flux-system namespace) to wait for a successful deployment, fetch the certificate from sealed-secrets pod log (flux-system namespace), and commit the file as ./demo/sealed-secrets.pem.

>Note: Replace the demo directory with a directory name that represents your cluster.

12) Create the flux-notifications directory:

```
mkdir -p ./demo/flux-notifications
```

>Note 1: Skip this step if you're not using Slack notifications.

>Note 2: Replace the demo directory with a directory name that represents your cluster.

13) Create the K8s secret for the slack-url (replace the Slack webhook placeholder with your webhook):

```
kubectl -n flux-system create secret generic slack-url --from-literal=address=https://hooks.slack.com/services/YOUR/SLACK/WEBHOOK --dry-run=client -o yaml | kubeseal --controller-name=sealed-secrets --controller-namespace=flux-system --format yaml --cert demo/sealed-secrets.pem > demo/flux-notifications/sealedsecret-flux-system-slack-url.yaml
```

>Note 1: Skip this step if you're not using Slack notifications.

>Note 2: Replace the demo directory with a directory name that represents your cluster.

14) Save the following content in a file named ./demo/flux-notifications/provider-flux-system-slack.yaml:

```
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Provider
metadata:
  name: slack
  namespace: flux-system
spec:
  type: slack
  channel: cluster-qa
  secretRef:
    name: slack-url
```

>Note 1: Skip this step if you're not using Slack notifications.

>Note 2: Replace the demo directory with a directory name that represents your cluster.

15) Save the following content in a file named ./demo/flux-notifications/alert-flux-system-slack-alerts.yaml:

```
apiVersion: notification.toolkit.fluxcd.io/v1beta1
kind: Alert
metadata:
  name: slack-alerts
  namespace: flux-system
spec:
  providerRef:
    name: slack
  eventSeverity: info
  eventSources:
    - kind: GitRepository
      name: '*'
    - kind: Kustomization
      name: '*'
    - kind: HelmRepository
      name: '*'
    - kind: HelmRelease
      name: '*'
```

>Note 1: Skip this step if you're not using Slack notifications.

>Note 2: Replace the demo directory with a directory name that represents your cluster.

16) Commit the ./demo/flux-notifications/sealedsecret-flux-system-slack-url.yaml, ./demo/flux-system/provider-flux-system-slack.yaml, and ./demo/flux-system/alert-flux-system-slack-alerts.yaml files.

>Note 1: Skip this step if you're not using Slack notifications.

>Note 2: Replace the demo directory with a directory name that represents your cluster.

## Code Dx Deployment

With the GitOps Toolkit deployed, you can run the Code Dx Guided Setup by selecting the `Flux v2 (GitOps Toolkit)` option. Running the Code Dx deployment script generated by the Guided Setup will create a GitOps directory whose contents you can commit at ./demo/Releases/Codedx for deployment via GitOps. 

The contents of the GitOps directory typically look like this:

```
├───ConfigMap
├───GitRepository
├───HelmRelease
├───Namespace
└───SealedSecret
```

Your resulting GitHub repository will have these directories:

```
├───demo
│   ├───flux-notifications
│   ├───flux-system
│   └───Releases
│       ├───CodeDx
│       │   ├───ConfigMap
│       │   ├───GitRepository
│       │   ├───HelmRelease
│       │   ├───Namespace
│       │   └───SealedSecret
│       └───SealedSecrets
│           ├───HelmRelease
│           └───HelmRepository
```