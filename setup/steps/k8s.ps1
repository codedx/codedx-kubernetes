
'./step.ps1',
'../core/common/input.ps1',
'../core/common/question.ps1',
'../core/common/k8s.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class ChooseEnvironment : Step {

	static [string] hidden $description = @'
Specify your Kubernetes provider so that the setup script can make options 
available for your type of Kubernetes cluster.

Note: Running Code Dx on AWS EKS requires a minimum Kubernetes version of 1.16.
'@

	ChooseEnvironment([ConfigInput] $config) : base(
		[ChooseEnvironment].Name, 
		$config,
		'Kubernetes Environment',
		[ChooseEnvironment]::description,
		'Where are you deploying Code Dx?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Minikube', 'Use Minikube for eval/test/dev purposes'),
			[tuple]::create('&AKS', 'Use Microsoft''s Azure Kubernetes Service (AKS)'),
			[tuple]::create('&EKS', 'Use Amazon''s Elastic Kubernetes Service (EKS)'),
			[tuple]::create('&Other', 'Use a different Kubernetes provider')), -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		switch (([MultipleChoiceQuestion]$question).choice) {
			0 { $this.config.k8sProvider = [ProviderType]::Minikube }
			1 { $this.config.k8sProvider = [ProviderType]::Aks }
			2 { $this.config.k8sProvider = [ProviderType]::Eks }
			3 { $this.config.k8sProvider = [ProviderType]::Other }
		}
		return $true
	}

	[void]Reset(){
		$this.config.k8sProvider = [ProviderType]::Other
	}
}

class ChooseContext : Step {

	static [string] hidden $description = @'
Specify the kubectl context where this install will take place so that the 
setup script can fetch configuration data.
'@

	static [string] hidden $noContext = 'I do not have a cluster'

	ChooseContext([ConfigInput] $config) : base(
		[ChooseContext].Name, 
		$config,
		'Kubectl Context',
		[ChooseContext]::description,
		'What''s the kubectl context for this deployment?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$contexts = Get-KubectlContexts
		$contexts | ForEach-Object {
			Write-Host $_
		}
		Write-Host
		
		$contextNames = Get-KubectlContexts -nameOnly
		$contextTuples = $contextNames | ForEach-Object {
			[tuple]::create($_, "Use the kubectl context named $_ for your deployment")
		}
		$contextTuples += [tuple]::create([ChooseContext]::noContext, "You do not have a cluster and need to create one first")

		return new-object MultipleChoiceQuestion($prompt, $contextTuples, -1)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$mcQuestion = [MultipleChoiceQuestion]$question
		$contextName = $mcQuestion.options[$mcQuestion.choice].item1.replace('&','')
		
		$this.config.kubeContextName = $contextName -eq [ChooseContext]::noContext ? '' : $contextName
		return $true
	}

	[void]Reset(){
		$this.config.kubeContextName = ''
	}
}

class HandleNoContext : Step {

	HandleNoContext([ConfigInput] $config) : base(
		[HandleNoContext].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		Write-Host 'Unable to continue because a Kuberenetes cluster is unavailable.'
		return $true
	}

	[bool]CanRun() {
		return -not $this.config.HasContext()
	}
}

class SelectContext: Step {

	SelectContext([ConfigInput] $config) : base(
		[SelectContext].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {
		Write-HostSection 'Select Kubectl Context' 'Selecting kubectl context...'
		Set-KubectlContext $this.config.kubeContextName

		$question = new-object YesNoQuestion("Continue with selected '$($this.config.kubeContextName)' context?",
			"Yes, continue with this context.",
			"No, select another context.", 0)
		
		$question.Prompt()
		if (-not $question.hasResponse) {
			return $false
		}
		return $question.choice -eq 0
	}

	[bool]CanRun() {
		return $this.config.HasContext()
	}
}

class GetKubernetesPort: Step {

	GetKubernetesPort([ConfigInput] $config) : base(
		[GetKubernetesPort].Name, 
		$config,
		'',
		'',
		'') {}

	[bool]Run() {

		Write-HostSection 'Kubernetes Port' 'This step fetches the Kubernetes port using the kubectl context you specified.'

		while ($true) {
			try {
				Write-Host "Determining Kubernetes port using '$($this.config.kubeContextName)' kubectl context...`n"
				$this.config.kubeApiTargetPort = Get-KubernetesPort
				break
			} catch {
				Write-Host "ERROR: Unable to read port from cluster (is the cluster up and running?):`n$_`n"
				$question = new-object YesNoQuestion("Try again?",
					"Yes, try again.",
					"No, go back to the previous step and select a different kubectl context.", 0)
				
				$question.Prompt()
				if (-not $question.hasResponse -or $question.choice -ne 0) {
					return $false
				}
			}
		}

		$question = new-object YesNoQuestion("Found Kubernetes port $($this.config.kubeApiTargetPort). Continue with this port?",
			"Yes, continue with this port.",
			"No, this port is incorrect.", 0)
		
		$question.Prompt()
		if (-not $question.hasResponse) {
			return $false
		}

		if ($question.choice -eq 1) {
			$question = new-object IntegerQuestion('Enter the port number for your Kubernetes port', 0, 65535, $false)
		
			$question.Prompt()
			if (-not $question.hasResponse) {
				return $false
			}

			$this.config.kubeApiTargetPort = $question.intResponse
		}

		return $true
	}

	[void]Reset() {
		$this.config.kubeApiTargetPort = [ConfigInput]::kubeApiTargetPortDefault
	}
}

class CertsCAPath : Step {

	static [string] hidden $description = @'
Specify a path to the CA associated with your Kubernetes Certificates API 
(certificates.k8s.io API). This may not be the same as your cluster's root CA.
'@

	static [string] hidden $aksDescription = @'
For AKS clusters, you can use two command prompt/terminal windows (with 
support for 'kubectl run -it') to fetch the CA cert. Run the following 
commands in order using a second  terminal window, running from your new 
directory, to complete the steps.

From Terminal 1: kubectl run --rm=true -it busybox --image=busybox --restart=Never
From Terminal 1: cp /var/run/secrets/kubernetes.io/serviceaccount/ca.crt /tmp/azure-aks.pem
From Terminal 2: kubectl cp busybox:/tmp/azure-aks.pem ./azure-aks.pem
From Terminal 1: exit
'@

	static [string] hidden $eksDescription = @'
For EKS clusters, open the EKS AWS console and download the base64 
representation of your cluster's CA certificate. Decode the certificate data 
and store it in a .pem file. On Linux, you can replace the 'encoded-cert-data' 
in the command below to generate an aws-eks.pem file for this step.

echo 'encoded-cert-data' | base64 -d > aws-eks.pem
'@

	static [string] hidden $minikubeDescription = @'
For Minikube clusters, you can find the CA file in the .minikube directory 
under your home profile folder 
'@

	CertsCAPath([ConfigInput] $config) : base(
		[CertsCAPath].Name, 
		$config,
		'Kubernetes Certificates API CA',
		'',
		'Enter the file path for your Kubernetes CA cert') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object CertificateFileQuestion($prompt, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.clusterCertificateAuthorityCertPath = ([CertificateFileQuestion]$question).response
		return $true
	}

	[string]GetMessage() {
		$message = [CertsCAPath]::description + "`n`n"
		switch ([int]$this.config.k8sProvider) {
			0 { $message += [CertsCAPath]::minikubeDescription + "($($env:HOME)/.minikube/ca.crt)." }
			1 { $message += [CertsCAPath]::aksDescription }
			2 { $message += [CertsCAPath]::eksDescription }
		}
		return $message
	}

	[void]Reset() {
		$this.config.clusterCertificateAuthorityCertPath = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipTLS
	}
}

class UsePrivateDockerRegistry : Step {

	static [string] hidden $description = @'
Specify whether you want to use a private Docker registry so that you can pull 
Docker images from sources that do not support anonymous access.
'@

	UsePrivateDockerRegistry([ConfigInput] $config) : base(
		[UsePrivateDockerRegistry].Name, 
		$config,
		'Docker Registry',
		[UsePrivateDockerRegistry]::description,
		'Do you want to use a private Docker registry?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes - I have a private Docker registry and would like to use it with Tool Orchestration', 
			'No - I will not be using private Docker images with Tool Orchestration', 1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipPrivateDockerRegistry = ([YesNoQuestion]$question).choice -eq 1
		return $true
	}

	[void]Reset(){
		$this.config.skipPrivateDockerRegistry = $false
	}
}

class DockerImagePullSecret : Step {

	static [string] hidden $description = @'
Specify the name of the Docker Image Pull Secret that the setup script will 
create to store your private Docker registry credential.
'@

	DockerImagePullSecret([ConfigInput] $config) : base(
		[DockerImagePullSecret].Name, 
		$config,
		'Docker Image Pull Secret',
		[DockerImagePullSecret]::description,
		'Enter a name for your Docker Image Pull Secret') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.dockerImagePullSecretName = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.dockerImagePullSecretName = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipPrivateDockerRegistry
	}
}

class PrivateDockerRegistryHost  : Step {

	static [string] hidden $description = @'
Specify the hostname for your private Docker registry. Use docker.io if you 
are using a private registry hosted on Docker Hub.
'@

	PrivateDockerRegistryHost([ConfigInput] $config) : base(
		[PrivateDockerRegistryHost].Name, 
		$config,
		'Docker Registry',
		[PrivateDockerRegistryHost]::description,
		'Enter your private Docker registry host (e.g., docker.io)') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.dockerRegistry = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.dockerRegistry = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipPrivateDockerRegistry
	}
}

class PrivateDockerRegistryUser  : Step {

	static [string] hidden $description = @'
Specify the username of a user with pull access to your private registry.
'@

	PrivateDockerRegistryUser([ConfigInput] $config) : base(
		[PrivateDockerRegistryUser].Name, 
		$config,
		'Docker Registry Username',
		[PrivateDockerRegistryUser]::description,
		'Enter your private Docker registry username') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.dockerRegistryUser = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.dockerRegistryUser = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipPrivateDockerRegistry
	}
}

class PrivateDockerRegistryPwd  : Step {

	PrivateDockerRegistryPwd([ConfigInput] $config) : base(
		[PrivateDockerRegistryPwd].Name, 
		$config,
		'Docker Registry Password',
		'',
		'Enter your private Docker registry password') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.dockerRegistryPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[string]GetMessage() {
		return "Specify the password for the $($this.config.dockerRegistryUser) account."
	}

	[void]Reset(){
		$this.config.dockerRegistryPwd = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipPrivateDockerRegistry
	}
}
