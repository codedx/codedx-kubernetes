
'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseDefaultDockerImages : Step {

	static [string] hidden $description = @'
Specify whether you want to use the default versions of Code Dx Docker images. 
You can specify one or more alternatives for each required Docker image, or you
can redirect all Docker references to another Docker registry. When redirecting, 
you must copy required Docker images to the registry.
'@

	static [string] hidden $descriptionPrivateAllowed = @'
Note: You specified configuration for a private Docker registry, so if you do 
not want to use the default Docker image versions, you can specify Docker 
images that reside in either a public registry or your private one.
'@

	static [string] hidden $descriptionPrivateNotAllowed = @'
Note: Since you did not specify configuration for a private Docker registry, 
if you do not want to use the default Docker image versions, you must 
specify Docker images stored in a registry that does not require a credential 
for pull access.
'@

	UseDefaultDockerImages([ConfigInput] $config) : base(
		[UseDefaultDockerImages].Name, 
		$config,
		'Code Dx Docker Images',
		'',
		'What Docker images do you want to use?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$options = @(
			[tuple]::create('&Default', 'Use the default set of Docker images'),
			[tuple]::create('&Custom',  'Specify one or more custom Docker images'),
			[tuple]::create('&Anonymous Redirect', 'Redirect Docker image requests to another registry (no login required)'))
		
		# cannot support private redirect on docker.io or w/o private registry details
		if ((-not ([string]::isnullorempty($this.config.dockerRegistry))) -and $this.config.dockerRegistry -notmatch 'docker.io$') {
			$options += ([tuple]::create('&Private Redirect', 'Redirect Docker image requests to your private registry'))
		}
		return new-object MultipleChoiceQuestion($prompt, $options, 0)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$choice = ([MultipleChoiceQuestion]$question).choice

		$this.config.useDefaultDockerImages = $choice -eq 0
		$this.config.useDockerRedirection   = $choice -ge 2

		if ($choice -eq 3) {
			$this.config.redirectDockerHubReferencesTo = $this.config.dockerRegistry
		}
		return $true
	}

	[string]GetMessage() {
		$note = [UseDefaultDockerImages]::descriptionPrivateAllowed
		if ($this.config.skipPrivateDockerRegistry) {
			$note = [UseDefaultDockerImages]::descriptionPrivateNotAllowed
		}
		return [UseDefaultDockerImages]::description + "`n`n" + $note
	}

	[void]Reset(){
		$this.config.useDefaultDockerImages = $false
		$this.config.useDockerRedirection   = $false
		$this.config.redirectDockerHubReferencesTo = ''
	}
}

class PublicRedirect : Step {

	static [string] hidden $description = @'
Specify the hostname for your Docker registry redirect. 

Note: The use of docker.io is not supported here (it would redirect to the 
Code Dx Docker images).
'@

	PublicRedirect([ConfigInput] $config) : base(
		[PublicRedirect].Name, 
		$config,
		'Docker Registry Redirect',
		[PublicRedirect]::description,
		'Enter your Docker registry host') {}

	[bool]HandleResponse([IQuestion] $question) {
		$response = ([Question]$question).response
		if ($response -match 'docker.io$') {
			return $false
		}
		$this.config.redirectDockerHubReferencesTo = $response
		return $true
	}

	[void]Reset(){
		$this.config.redirectDockerHubReferencesTo = ''
	}

	[bool]CanRun() {
		return $this.config.useDockerRedirection -and [string]::isnullorempty($this.config.redirectDockerHubReferencesTo)
	}
}

class DockerImageNameStep : Step {

	static [string] hidden $description = @'
You can use the default Docker image version by pressing Enter and accepting 
the default value, or you can specify a specific Docker image version.
'@

	static [string] hidden $descriptionPrivateAllowed = @'
Note: Since you specified configuration for a private Docker registry, you can 
specify a private Docker image that resides in your private registry.
'@

	static [string] hidden $descriptionPrivateNotAllowed = @'
Note: Since you did not specify configuration for a private Docker registry, 
you cannot specify a private Docker image here.
'@

	[string] $titleDetails
	
	DockerImageNameStep([string] $name,
		[ConfigInput] $config, 
		[string] $title,
		[string] $titleDetails,
		[string] $prompt) : base(
			$name, 
			$config,
			$title,
			'',
			$prompt) {
		$this.titleDetails = $titleDetails
	}

	[IQuestion]MakeQuestion([string] $prompt) {

		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		return $question
	}

	[string]GetMessage() {

		$note = [DockerImageNameStep]::descriptionPrivateAllowed
		if ($this.config.skipPrivateDockerRegistry) {
			$note = [DockerImageNameStep]::descriptionPrivateNotAllowed
		}
		return [DockerImageNameStep]::description + "`n`n" + $this.titleDetails + "`n`n" + $note
	}
}

class CodeDxTomcatDockerImage : DockerImageNameStep {

	CodeDxTomcatDockerImage([ConfigInput] $config) : base(
		[CodeDxTomcatDockerImage].Name, 
		$config,
		'Code Dx Tomcat Docker Image',
		'The Code Dx Tomcat Docker image packages the main Code Dx web application.',
		'Enter the Code Dx Tomcat Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxTomcat = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageCodeDxTomcat = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.useDockerRedirection
	}
}

class CodeDxTomcatInitDockerImage : DockerImageNameStep {

	CodeDxTomcatInitDockerImage([ConfigInput] $config) : base(
		[CodeDxTomcatInitDockerImage].Name, 
		$config,
		'Code Dx Tomcat Init Docker Image',
		'The Code Dx Tomcat Init Docker image handles the initialization of the Tomcat container.',
		'Enter the Code Dx Tomcat Init Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxTomcatInit = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageCodeDxTomcatInit = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.useDockerRedirection
	}
}

class CodeDxMariaDBDockerImage : DockerImageNameStep {

	CodeDxMariaDBDockerImage([ConfigInput] $config) : base(
		[CodeDxMariaDBDockerImage].Name, 
		$config,
		'Code Dx MariaDB Docker Image',
		'The Code Dx MariaDB Docker image is used to host the Code Dx database.',
		'Enter the Code Dx MariaDB Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageMariaDB = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageMariaDB = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipDatabase -and -not $this.config.useDockerRedirection
	}
}

class CodeDxToolsDockerImage : DockerImageNameStep {

	CodeDxToolsDockerImage([ConfigInput] $config) : base(
		[CodeDxToolsDockerImage].Name, 
		$config,
		'Code Dx Tools Docker Image',
		'The Code Dx Tools Docker image packages most of the Code Dx bundled tools.',
		'Enter the Code Dx Tools Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxTools = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageCodeDxTools = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxToolsMonoDockerImage : DockerImageNameStep {

	CodeDxToolsMonoDockerImage([ConfigInput] $config) : base(
		[CodeDxToolsMonoDockerImage].Name, 
		$config,
		'Code Dx Tools Mono Docker Image',
		'The Code Dx Tools Mono Docker image packages Code Dx bundled tools that depend on Mono.',
		'Enter the Code Dx Tools Mono Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxToolsMono = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageCodeDxToolsMono = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxToolServiceDockerImage : DockerImageNameStep {

	CodeDxToolServiceDockerImage([ConfigInput] $config) : base(
		[CodeDxToolServiceDockerImage].Name, 
		$config,
		'Code Dx Tool Service Docker Image',
		'The Code Dx Tool Service Docker image packages the Code Dx Tool Service.',
		'Enter the Code Dx Tool Service Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageToolService = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageToolService = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxSendResultsDockerImage : DockerImageNameStep {

	CodeDxSendResultsDockerImage([ConfigInput] $config) : base(
		[CodeDxSendResultsDockerImage].Name, 
		$config,
		'Code Dx Send Results Docker Image',
		'The Code Dx Tool Send Results Docker image packages the workflow step that sends results to Code Dx.',
		'Enter the Code Dx Send Results Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageSendResults = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageSendResults = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxSendErrorResultsDockerImage : DockerImageNameStep {

	CodeDxSendErrorResultsDockerImage([ConfigInput] $config) : base(
		[CodeDxSendErrorResultsDockerImage].Name, 
		$config,
		'Code Dx Send Error Results Docker Image',
		'The Code Dx Tool Send Error Results Docker image packages the workflow step that sends error results to Code Dx.',
		'Enter the Code Dx Send Error Results Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageSendErrorResults = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageSendErrorResults = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxNewAnalysisDockerImage : DockerImageNameStep {

	CodeDxNewAnalysisDockerImage([ConfigInput] $config) : base(
		[CodeDxNewAnalysisDockerImage].Name, 
		$config,
		'Code Dx New Analysis Docker Image',
		'The Code Dx New Analysis Docker image packages the workflow step that starts a new analysis in Code Dx.',
		'Enter the Code Dx New Analysis Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageNewAnalysis = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageNewAnalysis = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxPrepareDockerImage : DockerImageNameStep {

	CodeDxPrepareDockerImage([ConfigInput] $config) : base(
		[CodeDxPrepareDockerImage].Name, 
		$config,
		'Code Dx Prepare Docker Image',
		'The Code Dx Prepare Docker image prepares an orchestrated analysis.',
		'Enter the Code Dx Prepare Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imagePrepare = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imagePrepare = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxPreDeleteDockerImage : DockerImageNameStep {

	CodeDxPreDeleteDockerImage([ConfigInput] $config) : base(
		[CodeDxPreDeleteDockerImage].Name, 
		$config,
		'Code Dx Cleanup Docker Image',
		'The Code Dx Cleanup Docker image removes Tool Orchestration resources during an uninstall.',
		'Enter the Code Dx Cleanup Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imagePreDelete = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imagePreDelete = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class MinioDockerImage : DockerImageNameStep {

	MinioDockerImage([ConfigInput] $config) : base(
		[MinioDockerImage].Name, 
		$config,
		'MinIO Docker Image',
		'The MinIO Docker image provides workflow storage for Tool Orchestration.',
		'Enter the MinIO Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageMinio = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageMinio = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxWorkflowControllerDockerImage : DockerImageNameStep {

	CodeDxWorkflowControllerDockerImage([ConfigInput] $config) : base(
		[CodeDxWorkflowControllerDockerImage].Name, 
		$config,
		'Code Dx Workflow Controller Docker Image',
		'The Code Dx Workflow Controller Docker image is the Argo workflow controller for Tool Orchestration.',
		'Enter the Code Dx Workflow Controller Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageWorkflowController = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageWorkflowController = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}

class CodeDxWorkflowExecutorDockerImage : DockerImageNameStep {

	CodeDxWorkflowExecutorDockerImage([ConfigInput] $config) : base(
		[CodeDxWorkflowExecutorDockerImage].Name, 
		$config,
		'Code Dx Workflow Executor Docker Image',
		'The Code Dx Workflow Executor Docker image is the Argo workflow executor for Tool Orchestration.',
		'Enter the Code Dx Workflow Executor Docker image name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.imageWorkflowExecutor = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.imageWorkflowExecutor = ''
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration -and -not $this.config.useDockerRedirection
	}
}
