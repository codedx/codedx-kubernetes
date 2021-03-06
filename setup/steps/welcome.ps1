
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

class UseGitOps : Step {

	static [string] hidden $description = @'
Code Dx can generate a setup command that you can use to create GitOps 
outputs for deploying Code Dx on Kubernetes using fluxcd/helm-operator:

https://github.com/fluxcd/helm-operator

'@

	UseGitOps([ConfigInput] $config) : base(
		[UseGitOps].Name, 
		$config,
		'GitOps',
		[UseGitOps]::description,
		'Use GitOps?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, I want to deploy Code Dx using helm-operator', 
			'No, I don''t want to use GitOps', 1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$useGitOps = ([YesNoQuestion]$question).choice -eq 0
		$this.config.useHelmOperator = $useGitOps
		$this.config.skipSealedSecrets = -not $useGitOps
		return $true
	}

	[void]Reset() {
		$this.config.useHelmOperator = $false
		$this.config.skipSealedSecrets = $true
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
	static [string] hidden $kubesealDescription = @'

	- kubeseal (https://github.com/bitnami-labs/sealed-secrets/releases)
'@

	Prerequisites([ConfigInput] $config) : base(
		[Prerequisites].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		$useSealedSecrets = -not $this.config.skipSealedSecrets

		$prereqDescription = [Prerequisites]::description
		if (-not $this.config.skipSealedSecrets) {
			$prereqDescription += [Prerequisites]::kubesealDescription
		}
		Write-HostSection 'Prerequisites' $prereqDescription

		Write-Host 'Checking prerequisites...' -NoNewline; ([Step]$this).Delay()

		$prereqMessages = @()
		$this.config.prereqsSatisified = Test-SetupPreqs ([ref]$prereqMessages) -useSealedSecrets:$useSealedSecrets

		if (-not $this.config.prereqsSatisified) {

			Write-Host "The following issues were detected:`n"
			foreach ($prereqMessage in $prereqMessages) {
				Write-Host $prereqMessage
			}
			$this.config.missingPrereqs = [string]::Join("; ", $prereqMessages)
			
			Write-Host "`nFix the above issue(s) and restart this script`n"
			Read-HostEnter 'Press Enter to end...'

			return $true
		}
		Write-Host 'Done'
		
		return $this.ShouldProceed()
	}

	[bool]ShouldProceed() {

		$response = Read-HostChoice `
			"`nYour system meets the prerequisites. Do you want to continue?" `
			([tuple]::Create('Yes', 'Yes, continue running setup'),[tuple]::Create([question]::previousStepLabel, 'Go back to the previous step'))
			0

		return $response -eq 0
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

		if (-not (Test-Path $this.config.workDir -Type Container)) {
			try {
				New-Item -ItemType Directory $this.config.workDir | out-null
			} catch {
				Write-Host "Cannot create directory $($this.config.workDir): " $_
				$this.config.workDir = ''
				return $false
			}
		}

		return $true
	}
}
