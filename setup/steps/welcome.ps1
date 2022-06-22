
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

class DeploymentMethod : Step {

	static [string] hidden $description = @'
The Guided Setup will help you specify the Code Dx deployment script 
parameters based on your desired configuration and deployment method.

The deployment script supports the following deployment methods:

- Automated Helm Deployment (default)
- Manual Helm Deployment
- Flux v1 and Bitnami's Sealed Secrets
- Flux v2/GitOps Toolkit and Sealed Secrets
- Helm Manifest
- Helm Manifest with Sealed Secrets

Note: Enter '?' for deployment method descriptions.
'@

	DeploymentMethod([ConfigInput] $config) : base(
		[DeploymentMethod].Name, 
		$config,
		'Deployment Method',
		[DeploymentMethod]::description,
		'How would you like to deploy Code Dx?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Automated Helm', 'Deployment script will automate running helm with required resources'),
			[tuple]::create('&Manual Helm Deployment', 'Deployment script will generate required resources, values file(s), and helm command(s) to run manually'),
			[tuple]::create('&Flux v1', 'Deployment script will generate artifacts for use with Flux v1, helm-operator, and Bitnami''s Sealed Secrets'),
			[tuple]::create('Flux v2/&GitOps Toolkit', 'Deployment script will generate artifacts for use with Flux v2, helm-controller, and Bitnami''s Sealed Secrets'),
			[tuple]::create('&Helm Manifest', 'Deployment script will generate YAML resources using helm dry-run'),
			[tuple]::create('Helm Manifest with &Sealed Secrets', 'Deployment script will generate YAML resources using helm dry-run and Bitnami''s Sealed Secrets')), 0)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useHelmOperator = ([MultipleChoiceQuestion]$question).choice -eq 2
		$this.config.useHelmController = ([MultipleChoiceQuestion]$question).choice -eq 3
		$this.config.useHelmManifest = 4,5 -contains ([MultipleChoiceQuestion]$question).choice
		$this.config.skipSealedSecrets = 0,1,4 -contains ([MultipleChoiceQuestion]$question).choice
		$this.config.useHelmCommand = ([MultipleChoiceQuestion]$question).choice -eq 1
		return $true
	}

	[void]Reset() {
		$this.config.useHelmOperator = $false
		$this.config.useHelmController = $false
		$this.config.useHelmManifest = $false
		$this.config.skipSealedSecrets = $true
		$this.config.useHelmCommand = $false
	}
}

class HelmManifestWarning : Step {

	static [string] hidden $description = @'
The Code Dx deployment depends on Helm. The Code Dx deployment script 
can invoke helm on your behalf, generate resources for the Flux or
GitOps Toolkit helm operator, or generate a helm command that you can
run manually. This deployment method should only be used when you want to
deploy Code Dx using YAML files.

The Helm Manifest deployment option lets you use helm to render the YAML 
resources helm would produce during initial deployment. This option 
will not work on a cluster where you previously deployed Code Dx by 
applying helm-generated YAML. 

Warning: Upgrades must be performed by rerunning the deployment script 
on a cluster where Code Dx does not exist and manually merging the 
resulting YAML with previously generated YAML.

'@

	HelmManifestWarning([ConfigInput] $config) : base(
		[HelmManifestWarning].Name, 
		$config,
		'Helm Manifest Warning',
		[HelmManifestWarning]::description,
		'Do you understand the upgrade warning and want to continue?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Yes', 'Yes, I want to continue'),
			[tuple]::create('&No', 'No, I want to go back to the previous step')), 1)
	}

	[bool]Run() {
		Write-HostSection $this.title ($this.GetMessage())

		$question = $this.MakeQuestion($this.prompt)
		$question.Prompt()

		return $question.choice -eq 0
	}

	[bool]CanRun() {
		return $this.config.useHelmManifest
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
	- keytool (Java 8 JRE - https://adoptopenjdk.net/)
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

		Write-Host 'Checking prerequisites...'; ([Step]$this).Delay()

		$prereqMessages = @()
		$this.config.prereqsSatisified = Test-SetupPreqs ([ref]$prereqMessages) -useSealedSecrets:$useSealedSecrets -checkKubectlVersion:$false

		if (-not $this.config.prereqsSatisified) {
			$this.config.missingPrereqs = $prereqMessages
			Read-HostEnter "`nPress Enter to view missing prerequisites..."
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
updating your system/environment.

'@

	PrequisitesNotMet([ConfigInput] $config) : base(
		[PrequisitesNotMet].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		Write-HostSection 'Prequisites Not Met' ([PrequisitesNotMet]::description)

		Write-Host "The following issues were detected:`n"
		foreach ($prereqMessage in $this.config.missingPrereqs) {
			Write-Host $prereqMessage
		}

		Read-HostEnter "`nPress Enter to abort..."
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

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$q = [Question]$question
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
