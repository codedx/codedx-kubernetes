
'./step.ps1'
'../core/common/codedx.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseDefaultOptions : Step {

	static [string] hidden $description = @'
Specify what deployment options work best for your Kubernetes environment. 

Note: The Code Dx setup script can create Pod Security Policy (where 
available) and Network Policy resources, but your cluster must support those 
resource types for them to be active in your Kubernetes environment.
'@

	UseDefaultOptions([ConfigInput] $config) : base(
		[UseDefaultOptions].Name, 
		$config,
		'Deployment Options',
		[UseDefaultOptions]::description,
		'What options do you want to enable?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$defaultName = '&Pod Security Policy and Network Policy'
		$defaultDescription = 'Enable PSPs and Network Policies'

		if (-not $this.config.supportsPSPs) {
			$defaultName = '&Network Policy'
			$defaultDescription = 'Enable Network Policies'
		}

		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create($defaultName, $defaultDescription),
			[tuple]::create('&Other', 'Enable/disable each option individually')), 0)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$choice = ([MultipleChoiceQuestion]$question).choice

		$this.config.useDefaultOptions = $choice -eq 0
		$this.config.skipPSPs = (-not $this.config.supportsPSPs) -or $choice -eq 1
		$this.config.skipTLS  = $choice -eq 0
		$this.config.skipNetworkPolicies = $choice -eq 1
		return $true
	}

	[void]Reset() {
		$this.config.useDefaultOptions = $false
		$this.config.skipPSPs = $false
		$this.config.skipTLS = $false
		$this.config.skipNetworkPolicies = $false
	}
}

class UsePodSecurityPolicyOption : Step {

	static [string] hidden $description = @'
Specify whether you want to create Pod Security Policies, which determine 
what Kubernetes workloads can and cannot do on your cluster. Your cluster 
must support Pod Security Policies for the resources to apply.
'@

	UsePodSecurityPolicyOption([ConfigInput] $config) : base(
		[UsePodSecurityPolicyOption].Name, 
		$config,
		'Pod Security Policies',
		[UsePodSecurityPolicyOption]::description,
		'Install Pod Security Policies?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, install Pod Security Policies (requires cluster support)', 
			'No, I don''t want to install Pod Security Policies', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipPSPs = ([YesNoQuestion]$question).choice -eq 1
		return $true
	}

	[void]Reset() {
		$this.config.skipPSPs = $false
	}

	[bool]CanRun() {
		return $this.config.supportsPSPs -and -not $this.config.useDefaultOptions
	}
}

class UseNetworkPolicyOption : Step {

	static [string] hidden $description = @'
Specify whether you want to create Network Policies, which determine 
how Kubernetes workloads can communication on your cluster. Your cluster 
must support Network Policies for the resources to apply.
'@

	UseNetworkPolicyOption([ConfigInput] $config) : base(
		[UseNetworkPolicyOption].Name, 
		$config,
		'Network Policies',
		[UseNetworkPolicyOption]::description,
		'Install Network Policies?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, install Network Policies (requires cluster support)',
			'No, I don''t want to install Network Policies', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipNetworkPolicies = ([YesNoQuestion]$question).choice -eq 1
		return $true
	}

	[void]Reset(){
		$this.config.skipNetworkPolicies = $false
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultOptions
	}
}

class UseTlsOption : Step {

	static [string] hidden $description = @'
Specify whether you want to enable TLS between communications that support TLS.
'@

	UseTlsOption([ConfigInput] $config) : base(
		[UseTlsOption].Name, 
		$config,
		'Configure TLS',
		[UseTlsOption]::description,
		'Protect component communications using TLS (where available)?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to use TLS (where available)',
			'No, I don''t want to use TLS to secure component communications', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipTls = ([YesNoQuestion]$question).choice -eq 1
		return $true
	}

	[void]Reset(){
		$this.config.skipTls = $false
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultOptions
	}
}

class UseTriageAssistant : Step {

	static [string] hidden $description = @'
Do you plan to enable the Code Dx Triage Assistant? The Machine Learning 
Triage Assistant requires additional CPU and memory.
'@

	UseTriageAssistant([ConfigInput] $config) : base(
		[UseTriageAssistant].Name, 
		$config,
		'Use Triage Assistant',
		[UseTriageAssistant]::description,
		'Will your Code Dx deployment include the Triage Assistant?') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I plan to enable the Code Dx Triage Assistant',
			'No, I don''t plan to enable the Code Dx Triage Assistant', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useTriageAssistant = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.useTriageAssistant = $false
	}
}

class CodeDxNamespace : Step {

	static [string] hidden $description = @'
Specify the Kubernetes namespace where Code Dx components will be installed. 
For example, to install components in a namespace named 'cdx-app', enter  
that name here. The namespace will be created if it does not already exist.

Note: Press Enter to use the example namespace.
'@

	static [string] hidden $default = 'cdx-app'

	CodeDxNamespace([ConfigInput] $config) : base(
		[CodeDxNamespace].Name, 
		$config,
		'Code Dx Namespace',
		[CodeDxNamespace]::description,
		"Enter Code Dx namespace name (e.g., $([CodeDxNamespace]::default))") {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([CodeDxNamespace]::default))"
		$question.validationExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
		$question.validationHelp = 'The Code Dx namespace must consist of lowercase alphanumeric characters or ''-'', and must start and end with an alphanumeric character'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.namespaceCodeDx = ([Question]$question).GetResponse([CodeDxNamespace]::default)
		return $true
	}

	[void]Reset(){
		$this.config.namespaceCodeDx = [CodeDxNamespace]::default
	}
}

class CodeDxReleaseName : Step {

	static [string] hidden $description = @'
Specify the Helm release name for the Code Dx deployment. The name should not 
conflict with another Helm release in the Kubernetes namespace you chose.

If you plan to install multiple copies of the Code Dx Helm chart on a single 
cluster, specify a unique release name for each instance.

Note: Press Enter to use the example release name.
'@

	static [string] hidden $default = 'codedx'

	CodeDxReleaseName([ConfigInput] $config) : base(
		[CodeDxReleaseName].Name, 
		$config,
		'Code Dx Helm Release Name',
		[CodeDxReleaseName]::description,
		"Enter Code Dx Helm release name (e.g., $([CodeDxReleaseName]::default))") {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([CodeDxReleaseName]::default))"
		$question.validationExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
		$question.validationHelp = 'The Code Dx release name must consist of lowercase alphanumeric characters or ''-'', and must start and end with an alphanumeric character'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.releaseNameCodeDx = ([Question]$question).GetResponse([CodeDxReleaseName]::default)
		return $true
	}

	[void]Reset(){
		$this.config.releaseNameCodeDx = [CodeDxReleaseName]::default
	}
}

class CodeDxSignerName : Step {

	static [string] hidden $description = @'
Specify the signerName for the CertificateSigningRequests (CSR) required for 
components in the Code Dx namespace.
'@

	CodeDxSignerName([ConfigInput] $config) : base(
		[CodeDxSignerName].Name, 
		$config,
		'Code Dx CSR Signer',
		[CodeDxSignerName]::description,
		'Enter the Code Dx components CSR signerName') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.csrSignerNameCodeDx = ([Question]$question).GetResponse([CodeDxSignerName]::default)
		return $true
	}

	[void]Reset(){
		$this.config.csrSignerNameCodeDx = ''
	}
}

class CodeDxPassword : Step {

	static [string] hidden $description = @'
Specify the password you want to use for the Code Dx admin account. The 
password must be at least eight characters long.
'@
	
	CodeDxPassword([ConfigInput] $config) : base(
		[CodeDxPassword].Name, 
		$config,
		'Code Dx Password',
		[CodeDxPassword]::description,
		'Enter a password for the Code Dx admin account') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.minimumLength = 8
		return $question
	}
	
	[bool]HandleResponse([IQuestion] $question) {
		$this.config.codedxAdminPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.codedxAdminPwd = ''
	}
}
