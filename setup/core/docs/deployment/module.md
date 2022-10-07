# Guided Setup Module

Starting with the codedx-kubernetes release v2.12.0 (9/7/2022), the Code Dx Kubernetes deployment depends on the [guided-setup module](https://www.powershellgallery.com/packages/guided-setup) downloaded automatically from the [PowerShell Gallery](https://learn.microsoft.com/en-us/powershell/scripting/gallery/overview).

The PowerShell Gallery is untrusted by default. Running the Code Dx Kubernetes deployment will require trusting the repository by responding to the trust prompt with an affirmative reply:

```
Displaying available module repositories...
 - PSGallery at https://www.powershellgallery.com/api/v2 (Untrusted)

Trying to install guided-setup module...

Untrusted repository
You are installing the modules from an untrusted repository. If you trust this repository, change its
InstallationPolicy value by running the Set-PSRepository cmdlet. Are you sure you want to install the modules from
'PSGallery'?
[Y] Yes  [A] Yes to All  [N] No  [L] No to All  [S] Suspend  [?] Help (default is "N"):
```

You can avoid the above trust prompt by trusting the PowerShell Gallery repository ahead of time using this command (useful for non-interactive deployment environments):

```
PS >  Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
```

>Note: You can avoid trusting the PowerShell Gallery and a deployment-time dependency on PowerShell Gallery by following the [manual download instructions](https://github.com/codedx/codedx-kubernetes/blob/master/.install-guided-setup-module.ps1#L12).

### NuGet Alternative

Starting with v2.19.0, the guided-setup module is also available on [NuGet](https://www.nuget.org/packages/guided-setup). If you would prefer to avoid PowerShell Gallery, you can load the module from NuGet after running these commands:

```
PS >  Register-PSRepository -Name 'NuGet' -SourceLocation 'https://api.nuget.org/v3/index.json'
PS >  Set-PSRepository -Name 'NuGet' -InstallationPolicy 'Trusted'
PS >  Unregister-PSRepository 'PSGallery' # Remove PowerShell Gallery Repository
```