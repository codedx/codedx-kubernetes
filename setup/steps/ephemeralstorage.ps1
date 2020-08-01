'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class DefaultEphemeralStorage : Step {

	static [string] hidden $description = @'
Specify whether you want to make ephemeral storage reservations. A reservation 
will ensure your Code Dx workloads are placed on a node with sufficient 
resources. The recommended values are displayed below. Alternatively, you can 
skip making reservations or you can specify each reservation individually.
'@

	static [string] hidden $notes = @'
Note: You must make sure that your cluster has adequate storage resources to 
accommodate the resource requirements you specify. Failure to do so 
will cause Code Dx pods to get stuck in a Pending state.
'@

	DefaultEphemeralStorage([ConfigInput] $config) : base(
		[DefaultEphemeralStorage].Name, 
		$config,
		'Ephemeral Storage Reservations',
		'',
		'Use default ephemeral storage reservations?') { }

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Use Recommended', 'Use recommended reservations'),
			[tuple]::create('&Skip Reservations', 'Do not make reservations'),
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
		$this.config.useEphemeralStorageDefaults = $applyDefaults -or $mq.choice -eq 1
		return $true
	}

	[void]Reset(){
		$this.config.useEphemeralStorageDefaults = $false
	}

	[Step[]] GetSteps() {

		$steps = @()
		[NginxEphemeralStorage],[CodeDxEphemeralStorage],[MasterDatabaseEphemeralStorage],[SubordinateDatabaseEphemeralStorage],[ToolServiceEphemeralStorage],[MinIOEphemeralStorage],[WorkflowEphemeralStorage] | ForEach-Object {
			$step = new-object -type $_ -args $this.config
			if ($step.CanRun()) {
				$steps += $step
			}
		}
		return $steps
	}

	[string]GetMessage() {

		$message = [DefaultEphemeralStorage]::description + "`n`n" + [DefaultEphemeralStorage]::notes
		$message += "`n`nHere are the defaults (1024Mi =  1 Gibibyte):`n`n"
		$this.GetSteps() | ForEach-Object {
			$default = $_.GetDefault()
			if ('' -ne $default) {
				$message += "    {0}: {1}`n" -f (([EphemeralStorageStep]$_).title,$default)
			}
		}
		return $message
	}
}

class EphemeralStorageStep : Step {

	static [string] hidden $description = @'
Specify the amount of ephemeral storage to reserve in mebibytes (Mi) where 
1024 mebibytes is 1 gibibytes (Gi). Ephemeral storage is used by pods for 
logging, so high system activity may require more storage capacity. Making 
a reservation will set the Kubernetes resource limit and request 
parameters to the same value.

2048Mi =  2 Gibibyte
1024Mi =  1 Gibibyte
 512Mi = .5 Gibibyte

Pods may be evicted if ephemeral storage usage exceeds the reservation.

Note: You can skip making a reservation by accepting the default value.
'@

	[string] $title
	[string] $storage

	EphemeralStorageStep([string] $name, 
		[string] $title, 
		[ConfigInput] $config) : base($name, 
			$config,
			$title,
			[EphemeralStorageStep]::description,
			'Enter ephemeral storage reservation in mebibytes (e.g., 1024Mi)') {
		$this.title = $title
	}

	[IQuestion]MakeQuestion([string] $prompt) {

		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.validationExpr = '^[1-9]\d*(?:Mi)?$'
		$question.validationHelp = 'You entered an invalid value. Enter a value in mebibytes such as 1024Mi'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {

		if (-not $question.isResponseEmpty -and -not $question.response.endswith('Mi')) {
			$question.response += 'Mi'
		}

		return $this.HandleStorageResponse($question.response)
	}

	[bool]HandleStorageResponse([string] $storage) {
		throw [NotImplementedException]
	}

	[bool]CanRun() {
		return -not $this.config.useEphemeralStorageDefaults
	}
}

class NginxEphemeralStorage : EphemeralStorageStep {

	NginxEphemeralStorage([ConfigInput] $config) : base(
		[NginxEphemeralStorage].Name, 
		'NGINX Ephemeral Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.nginxEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.nginxEphemeralStorageReservation = ''
	}

	[void]ApplyDefault() {
		$this.config.nginxEphemeralStorageReservation = $this.GetDefault()
	}

	[bool]CanRun() {
		return ([EphemeralStorageStep]$this).CanRun() -and $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt
	}
}

class CodeDxEphemeralStorage : EphemeralStorageStep {

	CodeDxEphemeralStorage([ConfigInput] $config) : base(
		[CodeDxEphemeralStorage].Name, 
		'Code Dx Ephemeral Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.codeDxEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.codeDxEphemeralStorageReservation = '2048Mi'
	}

	[void]ApplyDefault() {
		$this.config.codeDxEphemeralStorageReservation = $this.GetDefault()
	}

	[string]GetDefault() {
		return '2048Mi'
	}
}

class MasterDatabaseEphemeralStorage : EphemeralStorageStep {

	MasterDatabaseEphemeralStorage([ConfigInput] $config) : base(
		[MasterDatabaseEphemeralStorage].Name, 
		'Master Database Ephemeral Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.dbMasterEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.dbMasterEphemeralStorageReservation = ''
	}

	[bool]CanRun() {
		return ([EphemeralStorageStep]$this).CanRun() -and (-not ($this.config.skipDatabase))
	}

	[void]ApplyDefault() {
		$this.config.dbMasterEphemeralStorageReservation = $this.GetDefault()
	}
}

class SubordinateDatabaseEphemeralStorage : EphemeralStorageStep {

	SubordinateDatabaseEphemeralStorage([ConfigInput] $config) : base(
		[SubordinateDatabaseEphemeralStorage].Name, 
		'Subordinate Database Ephermal Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.dbSlaveEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.dbSlaveEphemeralStorageReservation = ''
	}

	[bool]CanRun() {
		return ([EphemeralStorageStep]$this).CanRun() -and (-not ($this.config.skipDatabase)) -and $this.config.dbSlaveReplicaCount -gt 0
	}

	[void]ApplyDefault() {
		$this.config.dbSlaveEphemeralStorageReservation = $this.GetDefault()
	}
}

class ToolServiceEphemeralStorage : EphemeralStorageStep {

	ToolServiceEphemeralStorage([ConfigInput] $config) : base(
		[ToolServiceEphemeralStorage].Name, 
		'Tool Service Ephemeral Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.toolServiceEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.toolServiceEphemeralStorageReservation = ''
	}

	[bool]CanRun() {
		return ([EphemeralStorageStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}

	[void]ApplyDefault() {
		$this.config.toolServiceEphemeralStorageReservation = $this.GetDefault()
	}
}

class MinIOEphemeralStorage : EphemeralStorageStep {

	MinIOEphemeralStorage([ConfigInput] $config) : base(
		[MinIOEphemeralStorage].Name, 
		'MinIO Ephemeral Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.minioEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.minioEphemeralStorageReservation = ''
	}

	[bool]CanRun() {
		return ([EphemeralStorageStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}

	[void]ApplyDefault() {
		$this.config.minioEphemeralStorageReservation = $this.GetDefault()
	}
}

class WorkflowEphemeralStorage : EphemeralStorageStep {

	WorkflowEphemeralStorage([ConfigInput] $config) : base(
		[WorkflowEphemeralStorage].Name, 
		'Workflow Controller Ephemeral Storage Reservation', 
		$config) {}

	[bool]HandleStorageResponse([string] $storage) {
		$this.config.workflowEphemeralStorageReservation = $this.storage
		return $true
	}

	[void]Reset(){
		$this.config.workflowEphemeralStorageReservation = ''
	}

	[void]ApplyDefault() {
		$this.config.workflowEphemeralStorageReservation = $this.GetDefault()
	}

	[bool]CanRun() {
		return ([EphemeralStorageStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}
}
