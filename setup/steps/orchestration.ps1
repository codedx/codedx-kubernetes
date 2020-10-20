'./step.ps1',
'../core/common/input.ps1',
'../core/common/question.ps1',
'../core/common/codedx.ps1',
'../core/common/helm.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseToolOrchestration : Step {

	static [string] hidden $description = @'
Code Dx can orchestrate analyses that run on your Kubernetes cluster. The Tool 
Orchestration feature is a separately licensed Code Dx component. You can 
learn more by visiting the following URL:

https://codedx.com/blog/code-dx-enterprises-new-orchestration/
'@

	UseToolOrchestration([ConfigInput] $config) : base(
		[UseToolOrchestration].Name, 
		$config,
		'Tool Orchestration',
		[UseToolOrchestration]::description,
		'Install Tool Orchestration Components?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, I have a Code Dx license that includes Tool Orchestration', 
			'No, I don''t want to use Tool Orchestration at this time', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipToolOrchestration = ([YesNoQuestion]$question).choice -eq 1
		return $true
	}

	[void]Reset(){
		$this.config.skipToolOrchestration = $false
	}
}

class ToolOrchestrationNamespace : Step {

	static [string] hidden $description = @'
Specify the Kubernetes namespace where Code Dx Tool Orchestration components 
will be installed. For example, to install components in a namespace named 
'cdx-svc', enter that name here. The namespace will be created if it does 
not already exist.

Note: Press Enter to use the example namespace.
'@

	static [string] hidden $default = 'cdx-svc'

	ToolOrchestrationNamespace([ConfigInput] $config) : base(
		[ToolOrchestrationNamespace].Name, 
		$config,
		'Code Dx Tool Orchestration Namespace',
		[ToolOrchestrationNamespace]::description,
		"Enter Code Dx Tool Orchestration namespace name (e.g., $([ToolOrchestrationNamespace]::default))") {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([ToolOrchestrationNamespace]::default))"
		$question.validationExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
		$question.validationHelp = 'The Code Dx Tool Orchestration namespace must consist of lowercase alphanumeric characters or ''-'', and must start and end with an alphanumeric character'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.namespaceToolOrchestration = ([Question]$question).GetResponse([ToolOrchestrationNamespace]::default)
		return $true
	}

	[void]Reset(){
		$this.config.namespaceToolOrchestration = [ToolOrchestrationNamespace]::default
	}

	[bool]CanRun() {
		return -not $this.config.skipToolOrchestration
	}
}

class ToolOrchestrationReleaseName : Step {

	static [string] hidden $description = @'
Specify the Helm release name for the Code Dx Tool Orchestration deployment. 
The name should not conflict with another Helm release in the Kubernetes 
namespace you chose.

If you plan to install multiple copies of the Code Dx Tool Orchestration Helm 
chart on a single cluster, specify a unique release name for each instance.

Note: Press Enter to use the example release name.
'@

	static [string] hidden $default = 'codedx-tool-orchestration'

	ToolOrchestrationReleaseName([ConfigInput] $config) : base(
		[ToolOrchestrationReleaseName].Name, 
		$config,
		'Code Dx Tool Orchestration Helm Release',
		[ToolOrchestrationReleaseName]::description,
		"Enter Tool Orchestration Helm release name (e.g., $([ToolOrchestrationReleaseName]::default))") {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([ToolOrchestrationReleaseName]::default))"
		$question.validationExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
		$question.validationHelp = 'The Code Dx Tool Orchestration release name must consist of lowercase alphanumeric characters or ''-'', and must start and end with an alphanumeric character'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.releaseNameToolOrchestration = ([Question]$question).GetResponse([ToolOrchestrationReleaseName]::default)
		return $true
	}

	[void]Reset(){
		$this.config.releaseNameToolOrchestration = [ToolOrchestrationReleaseName]::default
	}

	[bool]CanRun() {
		return -not $this.config.skipToolOrchestration
	}
}

class ToolServiceKey : Step {

	static [string] hidden $description = @'
Specify the key you want to use for the Code Dx Tool Service. The key provides 
admin access to the tool orchestration system. The key must be at least eight 
characters long.
'@

	ToolServiceKey([ConfigInput] $config) : base(
		[ToolServiceKey].Name, 
		$config,
		'Code Dx Tool Service Password',
		[ToolServiceKey]::description,
		'Enter Code Dx Tool Service API key/password') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.minimumLength = 8
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.toolServiceApiKey = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.toolServiceApiKey = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipToolOrchestration
	}
}

class MinioAdminPassword : Step {

	static [string] hidden $description = @'
Specify the password you want to use for the MinIO admin account. The 
password must be at least eight characters long.
'@

	MinioAdminPassword([ConfigInput] $config) : base(
		[MinioAdminPassword].Name, 
		$config,
		'MinIO Password',
		[MinioAdminPassword]::description,
		'Enter a password for the MinIO admin account') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.minimumLength = 8
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.minioAdminPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.minioAdminPwd = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipToolOrchestration
	}
}

class ToolServiceReplicaCount : Step {

	static [string] hidden $description = @'
Specify the number of tool service instances that you want to run. Having more 
than one tool service can keep the service online when a single instance fails.
You must run at least one service instance.
'@

	ToolServiceReplicaCount([ConfigInput] $config) : base(
		[ToolServiceReplicaCount].Name, 
		$config,
		'Tool Service Replicas',
		[ToolServiceReplicaCount]::description,
		'Enter the number of tool service replicas') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object IntegerQuestion($prompt, 1, ([int]::maxvalue), $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.toolServiceReplicas = ([IntegerQuestion]$question).intResponse
		return $true
	}

	[void]Reset(){
		$this.config.toolServiceReplicas = [ConfigInput]::toolServiceReplicasDefault
	}

	[bool]CanRun() {
		return -not $this.config.skipToolOrchestration
	}
}
