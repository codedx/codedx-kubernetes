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
Specify whether you want to use the recommended memory reservations displayed 
below. A reservation will ensure your Code Dx workloads are placed on a 
node with sufficient memory resources. You can specify each memory reservation 
individually by responding with the No option. If you want to skip making 
reservations, select No and press Enter to accept the default value for 
each memory question.
'@

	DefaultMemory([ConfigInput] $config) : base(
		[DefaultMemory].Name, 
		$config,
		'Memory Reservations',
		[DefaultMemory]::description,
		'Use default memory reservations?') { }

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, do not specify a memory reservation for each component', 
			'No, specify a memory reservation for each component', 0)
	}

	[void]HandleResponse([IQuestion] $question) {

		$applyDefaults = $question.choice -eq 0
		if ($applyDefaults) {
			$this.GetSteps() | ForEach-Object {
				$_.ApplyDefault()
			}
		}
		$this.config.useMemoryDefaults = $applyDefaults
	}

	[void]Reset(){
		$this.config.useMemoryDefaults = $false
	}

	[Step[]] GetSteps() {

		$steps = @()
		[NginxMemory],[CodeDxMemory],[MasterDatabaseMemory],[SubordinateDatabaseMemory],[ToolServiceMemory],[MinIOMemory],[WorkflowMemory] | ForEach-Object {
			$step = new-object -type $_ -args $this.config
			if ($step.CanRun()) {
				$steps += $step
			}
		}
		return $steps
	}

	[string]GetMessage() {

		$message = "You can use default Memory reservations for Code Dx components.`n`nNote: You must make sure that your cluster has adequate resources to accommodate default resource requirements"
		$message += "`n`nHere are the defaults:`n`n"
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

	[void]HandleResponse([IQuestion] $question) {

		if (-not $question.isResponseEmpty -and -not $question.response.endswith('Mi')) {
			$question.response += 'Mi'
		}

		$this.HandleMemoryResponse($question.response)
	}

	[void]HandleMemoryResponse([string] $cpu) {
		throw [NotImplementedException]
	}

	[bool]CanRun() {
		return -not $this.config.useMemoryDefaults
	}
}

class NginxMemory : MemoryStep {

	NginxMemory([ConfigInput] $config) : base(
		[NginxMemory].Name, 
		'NGINX Memory Reservation', 
		$config) {}

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.nginxMemoryReservation = $memory
	}

	[void]Reset(){
		$this.config.nginxMemoryReservation = ''
	}

	[void]ApplyDefault() {
		$this.config.nginxMemoryReservation = $this.GetDefault()
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt
	}

	[string]GetDefault() {
		return '500Mi'
	}
}

class CodeDxMemory : MemoryStep {

	CodeDxMemory([ConfigInput] $config) : base(
		[CodeDxMemory].Name, 
		'Code Dx Memory Reservation', 
		$config) {}

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.codeDxMemoryReservation = $memory
	}

	[void]Reset(){
		$this.config.codeDxMemoryReservation = ''
	}

	[void]ApplyDefault() {
		$this.config.codeDxMemoryReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return '8192Mi'
	}
}

class MasterDatabaseMemory : MemoryStep {

	MasterDatabaseMemory([ConfigInput] $config) : base(
		[MasterDatabaseMemory].Name, 
		'Master Database Memory Reservation', 
		$config) {}

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.dbMasterMemoryReservation = $memory
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

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.dbSlaveMemoryReservation = $memory
	}

	[void]Reset(){
		$this.config.dbSlaveMemoryReservation = ''
	}

	[bool]CanRun() {
		return ([MemoryStep]$this).CanRun() -and (-not ($this.config.skipDatabase))
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

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.toolServiceMemoryReservation = $memory
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

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.minioMemoryReservation = $memory
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

	[void]HandleMemoryResponse([string] $memory) {
		$this.config.workflowMemoryReservation = $memory
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
