
'./step.ps1',
'../core/common/input.ps1',
'../core/common/codedx.ps1',
'../core/common/helm.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class Welcome : Step {

	Welcome([ConfigInput] $config) : base(
		[Welcome].Name, 
		$config, 
		'', 
		'', 
		'') {}

	[bool]Run() {
		write-host "XXXXXXXXXXXXXNWWMMMMMMMMMMMMMMMMMMMMMMMM"
		write-host "ccccccccccccclodkKNMMMMMMMMMMMMMMMMMMMMM"
		write-host ",,,,,,,,,,,,,,,,,;lkKXMMMMMMMMMMMMMMMMMM"
		write-host ",,,,,,,,,,,,,,,,,,,;;l0WMMMMMMMMMMMMMMMM"
		write-host ",,,,,;oO0000Oxl;,,,,,,:OWMMMMMMMMMMMMMMM"
		write-host ",,,,,;kWMMMMMWNk:,,,,,,c0WMMMMMMMMMMMMMW"
		write-host ",,,,,;kWMMMMMMMNx;,,,,,;xNMMMMMMMMMMMNOO"
		write-host ",,,,,;kWMMMMMMMM0c,,,,,,oXMMMMMMMMMNxcdX"
		write-host ",,,,,;kWMMMMMMMMKo;;;;;;oXMMMMMMMNx,'dNM"
		write-host ",,,,,;kWMMMMMMMMWXKKKKKKXWMMMMMNx,.'kWMM"
		write-host ",,,,,;kWMMMMMMMMXxc:::::oKMMMXd,  ,0WMMM"
		write-host ",,,,,;kNWWWWNX0KNO,      ,kKd'   :KMMMMM"
		write-host ",,,,,,:llloll:;:kNKl'.    ..   .lXMMMMMM"
		write-host ",,,,,,,,,,,,,,,,;dXNXx.       .dNMMMMMMM"
		write-host ",,,,,,,,,,,,,,,;cdKWMWO,     .oNMMMMMMMM"
		write-host "kkkkkkkkkkkkkO0KNWMMMWO:.   .':xNMMMMMMM"
		write-host "MMMMMMMMMMMMMMMMMMWX0x:,,...',,;oKWMMMMM"
		write-host "MMMMMMMMMMMMMMMMMW0l;;,,,:oo;,,,,cOWMMMM"
		write-host "MMMMMMMMMMMMMMMMNk:,,,,,:ONNk:,,,,:xXMMM"
		write-host "MMMMMMMMMMMMMMMWk:,,,,,;kWMMWk:,,,,;xNMM"
		Write-Host "`nWelcome to the Code Dx Kubernetes Guided Setup!`n"
		Read-HostEnter
		return $true
	}
}

class Prerequisites : Step {

	static [string] hidden $description = @'
Your system must meet these prerequisites to run the Code Dx setup scripts:

	- PowerShell Core (v7+)
	- helm v3.1+ (https://github.com/helm/helm/releases/tag/v3.2.4)
	- kubectl (https://kubernetes.io/docs/tasks/tools/install-kubectl/)
	- openssl (https://www.openssl.org/)
	- git (https://git-scm.com/book/en/v2/Getting-Started-Installing-Git)
	- keytool (Java JRE - https://adoptopenjdk.net/)
'@

	Prerequisites([ConfigInput] $config) : base(
		[Prerequisites].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		Write-HostSection 'Prerequisites' ([Prerequisites]::description)

		Write-Host 'Checking prerequisites...' -NoNewline; ([Step]$this).Delay()

		$prereqMessages = @()
		$this.config.prereqsSatisified = Test-SetupPreqs ([ref]$prereqMessages)

		if (-not $this.config.prereqsSatisified) {

			Write-Host "The following issues were detected:`n"
			foreach ($prereqMessage in $prereqMessages) {
				Write-Host $prereqMessage
			}
			$this.config.missingPrereqs = [string]::Join("; ", $prereqMessages)
			
			Write-Host "`nFix the above issue(s) and restart this script`n"
			Read-HostEnter 'Press Enter to end...'
		} else {

			Write-Host "Done`n"
			Read-HostEnter
		}

		return $true
	}
}

class PrequisitesNotMet : Step {

	static [string] hidden $description = @'
Your system does not meet the prerequisites. Rerun this script after 
updating your system to meet the following prerequisites:

'@

	PrequisitesNotMet([ConfigInput] $config) : base(
		[PrequisitesNotMet].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		Write-HostSection 'Prequisites Not Met' ([PrequisitesNotMet]::description)
		Write-Host $this.config.missingPrereqs
		return $true
	}

	[bool]CanRun() {
		return -not $this.config.prereqsSatisified
	}
}

class WorkDir : Step {

	static [string] hidden $description = @'
Specify a directory to store files generated during the setup process. Files 
in your work directory may contain data that should be kept private.
'@

	[string] $homeDirectory = $HOME

	WorkDir([ConfigInput] $config) : base(
		[WorkDir].Name, 
		$config,
		'Work Directory',
		[WorkDir]::description,
		"Enter a directory or press Enter to accept the default ($HOME/.k8s-codedx)") {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object PathQuestion($prompt, [microsoft.powershell.commands.testpathtype]::Container, $true)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$q = [PathQuestion]$question
		$this.config.workDir = $q.isResponseEmpty ? "$($this.homeDirectory)/.k8s-codedx" : $q.response
		return $true
	}
}
