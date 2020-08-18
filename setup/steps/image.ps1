
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
		'Do you want to use the default Docker images?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to use the latest Code Dx Docker images',
			'No, I want to specify versions of Code Dx Docker images', 0)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useDefaultDockerImages = ([YesNoQuestion]$question).choice -eq 0
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
		return -not $this.config.useDefaultDockerImages
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
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
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
	}
}