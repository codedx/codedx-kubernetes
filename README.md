
# Deploy Code Dx on Kubernetes

Running guided-setup.ps1 is the recommended way to deploy Code Dx on Kubernetes (requires [PowerShell Core 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7)). The script will help you specify the correct setup.ps1 script parameters for installing Code Dx on your Kubernetes cluster.

You must run the script from a system with administrative access to your cluster. Here are the script prerequisites:

- [git](https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
- [PowerShell Core 7](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7)
- [kubectl](https://kubernetes.io/docs/tasks/tools/install-kubectl/)
- [openssl](https://www.openssl.org/)
- [keytool](https://adoptopenjdk.net/) - The keytool application is bundled with the Java JRE.
- [helm v3.1+](https://github.com/helm/helm/releases/tag/v3.2.4) - Download the Helm release for your platform and extract helm (or helm.exe) to a directory in your PATH environment variable.

With prerequisites installed, open a Command Prompt/Terminal window and clone this repository on your system by running the following command from the directory where you want to store the codedx-kubernetes files:

```
git clone https://github.com/codedx/codedx-kubernetes.git -b feature/guide
```

To run the guided setup script, change directory to codedx-kubernetes, and use pwsh to run general-setup.ps1:

```
cd codedx-kubernetes
pwsh ./guided-setup.ps1
```

The guided setup script checks to see whether your system meets the prerequisites before presenting questions with a series of steps (shown below) to help you specify the setup.ps1 parameters necessary to deploy Code Dx in your Kubernetes environment.

![Guided Setup Flow](./images/guided-setup.svg)
