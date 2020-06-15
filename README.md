
# Deploy Code Dx on Kubernetes

Running guided-setup.ps1 is the recommended way to deploy Code Dx on Kubernetes (k8s). 

The guided setup script requires PowerShell Core 7 that you can install by following the [installation instructions](https://docs.microsoft.com/en-us/powershell/scripting/install/installing-powershell?view=powershell-7). You can check what version of PowerShell Core you have installed by running `pwsh --version`.

To run the script, download general-setup.ps1 from this folder and run the following command:

pwsh ./guided-setup.ps1

The script checks to see whether your system meets specific prerequisites before prompting for details necessary to deploy Code Dx in your k8s environment.

