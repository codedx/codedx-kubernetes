
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

	UseDefaultDockerImages([ConfigInput] $config) : base(
		[UseDefaultDockerImages].Name, 
		$config,
		'Code Dx Docker Images',
		[UseDefaultDockerImages]::description,
		'Do you want to use the default Docker images?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to use the latest Code Dx Docker images',
			'No, I want to specify versions of Code Dx Docker images', 0)
	}

	[void]HandleResponse([IQuestion] $question) {
		$this.config.useDefaultDockerImages = ([YesNoQuestion]$question).choice -eq 0
	}

	[string]GetMessage() {
		$message = [UseDefaultDockerImages]::description + [UseDefaultDockerImages]::descriptionPrivateAllowed
		if ($this.config.skipPrivateDockerRegistry) {
			$message = [UseDefaultDockerImages]::description + [UseDefaultDockerImages]::descriptionPrivateNotAllowed
		}
		return $message
	}

	[void]Reset(){
		$this.config.useDefaultDockerImages = $false
	}
}

class DockerImageNameStep : Step {

	static [string] hidden $description = @'
You can use the latest versions of Code Dx Docker images or you can specify 
specific versions.

'@

	static [string] hidden $descriptionPrivateAllowed = @'

You entered configuration for a private Docker registry, so you can specify 
private Docker images names here.
'@

	static [string] hidden $descriptionPrivateNotAllowed = @'

Since you did not enter configuration for a private Docker registry, you 
cannot specify private Docker images names here.
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

	[string]GetMessage() {

		$message = [UseDefaultDockerImages]::description + $this.titleDetails + [UseDefaultDockerImages]::descriptionPrivateAllowed
		if ($this.config.skipPrivateDockerRegistry) {
			$message = [UseDefaultDockerImages]::description + $this.titleDetails + [UseDefaultDockerImages]::descriptionPrivateNotAllowed
		}
		return $message
	}
}

class CodeDxTomcatDockerImage : DockerImageNameStep {

	CodeDxTomcatDockerImage([ConfigInput] $config) : base(
		[CodeDxTomcatDockerImage].Name, 
		$config,
		'Code Dx Tomcat Docker Image',
		'The Code Dx Tomcat Docker image packages the main Code Dx web application.',
		'Enter the Code Dx Tomcat Docker image name') {}

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxTomcat = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageCodeDxTomcat = 'codedx/codedx-tomcat:v5.0.8'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxTools = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageCodeDxTools = 'codedx/codedx-tools:v1.0.3'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageCodeDxToolsMono = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageCodeDxToolsMono = 'codedx/codedx-toolsmono:v1.0.3'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageToolService = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageToolService = 'codedx/codedx-tool-service:v1.0.2'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageSendResults = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageSendResults = 'codedx/codedx-results:v1.0.0'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageSendErrorResults = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageSendErrorResults = 'codedx/codedx-error-results:v1.0.0'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imageNewAnalysis = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imageNewAnalysis = 'codedx/codedx-newanalysis:v1.0.0'
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

	[void]HandleResponse([IQuestion] $question) {
		$this.config.imagePreDelete = ([Question]$question).response
	}

	[void]Reset(){
		$this.config.imagePreDelete = 'codedx/codedx-cleanup:v1.0.0'
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultDockerImages -and -not $this.config.skipToolOrchestration
	}
}