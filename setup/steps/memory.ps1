'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class DefaultMemory : Step {

	static [string] hidden $description = @'
Specify whether you want to make memory reservations. A reservation will 
ensure your Code Dx workloads are placed on a node with sufficient resources. 
The recommended values are displayed below. Alternatively, you can skip making 
reservations or you can specify each reservation individually.
'@

	static [string] hidden $notes = @'
Note: You must make sure that your cluster has adequate memory resources to 
accommodate the resource requirements you specify. Failure to do so 
will cause Code Dx pods to get stuck in a Pending state.
'@

	DefaultMemory([ConfigInput] $config) : base(
		[DefaultMemory].Name, 
		$config,
		'Memory Reservations',
		'',
		'Make memory reservations?') { }

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Use Recommended', 'Use recommended reservations'),
			[tuple]::create('&Custom', 'Make reservations on a per-component basis')), 0)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$mq = [MultipleChoiceQuestion]$question
		$applyDefaults = $mq.choice -eq 0
		if ($applyDefaults) {
			$this.GetSteps() | ForEach-Object {
				$_.ApplyDefault()
			}
		}
		$this.config.useMemoryDefaults = $applyDefaults
		return $true
	}

	[void]Reset(){
		$this.config.useMemoryDefaults = $false
	}

	[Step[]] GetSteps() {

		$steps = @()
		[CodeDxMemory],[MasterDatabaseMemory],[SubordinateDatabaseMemory],[ToolServiceMemory],[MinIOMemory],[WorkflowMemory] | ForEach-Object {
			$step = new-object -type $_ -args $this.config
			if ($step.CanRun()) {
				$steps += $step
			}
		}
		return $steps
	}

	[string]GetMessage() {

		$message = [DefaultMemory]::description + "`n`n" + [DefaultMemory]::notes
		$message += "`n`nHere are the defaults (1024Mi =  1 Gibibyte):`n`n"
		$this.GetSteps() | ForEach-Object {
			$default = $_.GetDefault()
			if ('' -ne $default) {
				$message += "    {0}: {1}`n" -f (([MemoryStep]$_).title,$default)
			}
		}
		return $message
	}
}

class MemoryStep : Step {

	static [string] hidden $description = @'
Specify the amount of memory to reserve in mebibytes (Mi) where 1024 mebibytes 
is 1 gibibytes (Gi). Making a reservation will set the Kubernetes resource 
limit and request parameters to the same value.

2048Mi =  2 Gibibyte
1024Mi =  1 Gibibyte
 512Mi = .5 Gibibyte

Pods may be evicted if memory usage exceeds the reservation.

Note: You can skip making a reservation by accepting the default value.
'@

	MemoryStep([string] $name, 
		[string] $title, 
		[ConfigInput] $config) : base($name, 
			$config,
			$title,
			[MemoryStep]::description,
			'Enter memory reservation in mebibytes (e.g., 500Mi)') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question('Enter memory reservation in mebibytes (e.g., 500Mi)')
		$question.allowEmptyResponse = $true
		$question.validationExpr = '^[1-9]\d*(?:Mi)?$'
		$question.validationHelp = 'You entered an invalid value. Enter a value in mebibytes such as 1024Mi'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {

		if (-not $question.isResponseEmpty -and -not $question.response.endswith('Mi')) {
			$question.response += 'Mi'
		}

		$response = $question.response
		if ($question.isResponseEmpty) {
			$response = $this.GetDefault()
		}

		return $this.HandleMemoryResponse($response)
	}

	[bool]HandleMemoryResponse([string] $cpu) {
		throw [NotImplementedException]
	}

	[bool]CanRun() {
		return -not $this.config.useMemoryDefaults
	}
}

class CodeDxMemory : MemoryStep {

	CodeDxMemory([ConfigInput] $config) : base(
		[CodeDxMemory].Name, 
		'Code Dx Memory Reservation', 
		$config) {}

	[bool]HandleMemoryResponse([string] $memory) {
		$this.config.codeDxMemoryReservation = $memory
		return $true
	}

	[void]Reset(){
		$this.config.codeDxMemoryReservation = ''
	}

	[void]ApplyDefault() {
		$this.config.codeDxMemoryReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return $this.config.useTriageAssistant ? '16384Mi' : '8192Mi'
	}
}

class MasterDatabaseMemory : MemoryStep {

	MasterDatabaseMemory([ConfigInput] $config) : base(
		[MasterDatabaseMemory].Name, 
		'Master Database Memory Reservation', 
		$config) {}

	[bool]HandleMemoryResponse([string] $memory) {
		$this.config.dbMasterMemoryReservation = $memory
		return $true
	}

	[void]Reset(){
		$this.config.dbMasterMemoryReservation = ''
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and (-not ($this.config.skipDatabase))
	}

	[void]ApplyDefault() {
		$this.config.dbMasterMemoryReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return '8192Mi'
	}
}

class SubordinateDatabaseMemory : MemoryStep {

	SubordinateDatabaseMemory([ConfigInput] $config) : base(
		[SubordinateDatabaseMemory].Name, 
		'Subordinate Database Memory Reservation', 
		$config) {}

	[bool]HandleMemoryResponse([string] $memory) {
		$this.config.dbSlaveMemoryReservation = $memory
		return $true
	}

	[void]Reset(){
		$this.config.dbSlaveMemoryReservation = ''
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and (-not ($this.config.skipDatabase)) -and $this.config.dbSlaveReplicaCount -gt 0
	}

	[void]ApplyDefault() {
		$this.config.dbSlaveMemoryReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return '8192Mi'
	}
}

class ToolServiceMemory : MemoryStep {

	ToolServiceMemory([ConfigInput] $config) : base(
		[ToolServiceMemory].Name, 
		'Tool Service Memory Reservation', 
		$config) {}

	[bool]HandleMemoryResponse([string] $memory) {
		$this.config.toolServiceMemoryReservation = $memory
		return $true
	}

	[void]Reset(){
		$this.config.toolServiceMemoryReservation = ''
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}

	[void]ApplyDefault() {
		$this.config.toolServiceMemoryReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return '500Mi'
	}
}

class MinIOMemory : MemoryStep {

	MinIOMemory([ConfigInput] $config) : base(
		[MinIOMemory].Name, 
		'MinIO Memory Reservation', 
		$config) {}

	[bool]HandleMemoryResponse([string] $memory) {
		$this.config.minioMemoryReservation = $memory
		return $true
	}

	[void]Reset(){
		$this.config.minioMemoryReservation = ''
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}

	[void]ApplyDefault() {
		$this.config.minioMemoryReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return '5120Mi'
	}
}

class WorkflowMemory : MemoryStep {

	WorkflowMemory([ConfigInput] $config) : base(
		[WorkflowMemory].Name, 
		'Workflow Controller Memory Reservation', 
		$config) {}

	[bool]HandleMemoryResponse([string] $memory) {
		$this.config.workflowMemoryReservation = $memory
		return $true
	}

	[void]Reset(){
		$this.config.workflowMemoryReservation = ''
	}

	[void]ApplyDefault() {
		$this.config.workflowMemoryReservation = $this.GetDefault()
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}

	[string]GetDefault() {
		return '500Mi'
	}
}
