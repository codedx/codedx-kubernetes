'./step.ps1',
'../core/common/input.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class BackupType : Step {

	static [string] hidden $description = @'
You can back up Code Dx with Velero using storage provider plug-ins or its 
Restic integration. Refer to https://velero.io/docs for Velero installation 
instructions. Code Dx has been tested with Velero 1.3, 1.4, and 1.5.

If you choose to use Velero, a new Schedule resource will get created from 
the information you provide, so you must install and configure Velero before 
deploying Code Dx.
'@

	static [string] hidden $externalDatabaseDescription = @'


IMPORTANT NOTE: You chose to use an external Code Dx database, so you must 
back up the database on your own at a time that coincides with the Code Dx 
backup schedule.
'@

	BackupType([ConfigInput] $config) : base(
		[BackupType].Name, 
		$config,
		'Backup Type',
		[BackupType]::description,
		'How will you back up Code Dx?') {}

	[string]GetMessage() {

		$message = [BackupType]::description
		if ($this.config.skipDatabase) {
			$message += [BackupType]::externalDatabaseDescription
		}
		return $message
	}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Skip', 'Skip Code Dx back up support'),
			[tuple]::create('&Velero (Plug-ins)', 'Use Velero with storage provider plug-ins'),
			[tuple]::create('Velero (&Restic)', 'Use Velero''s Restic integration')), 0)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$multipleChoiceQuestion = ([MultipleChoiceQuestion]$question)
		switch ($multipleChoiceQuestion.choice) {
			0 { $this.config.backupType = '' }
			1 { $this.config.backupType = 'velero' }
			2 { $this.config.backupType = 'velero-restic' }
		}
		return $true
	}

	[void]Reset(){
		$this.config.backupType = ''
	}
}

class VeleroNamespace : Step {

	static [string] hidden $description = @'
Specify the Kubernetes namespace that contains a Velero deployment.

Note: Press Enter to use the default namespace.
'@

	static [string] hidden $default = 'velero'

	VeleroNamespace([ConfigInput] $config) : base(
		[VeleroNamespace].Name, 
		$config,
		'Velero Namespace',
		[VeleroNamespace]::description,
		"Enter Velero namespace name (e.g., $([VeleroNamespace]::default))") {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([VeleroNamespace]::default))"
		$question.validationExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
		$question.validationHelp = 'The Velero namespace must consist of lowercase alphanumeric characters or ''-'', and must start and end with an alphanumeric character'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.namespaceVelero = ([Question]$question).GetResponse([VeleroNamespace]::default)
		return $true
	}

	[bool]CanRun() {
		return $this.config.IsUsingVelero()
	}

	[void]Reset(){
		$this.config.namespaceVelero = ''
	}
}

class BackupSchedule : Step {

	static [string] hidden $description = @'
Specify when to run a backup by entering a cron expression. You can use the 
following default expression to run back up Code Dx at 3:00 AM (UTC):

0 3 * * *

Refer to the following URL for details on how to define a CRON expression:

https://en.wikipedia.org/wiki/Cron#CRON_expression

Note: Press Enter to use the default expression.
'@

	static [string] hidden $default = '0 3 * * *'

	BackupSchedule([ConfigInput] $config) : base(
		[BackupSchedule].Name, 
		$config,
		'Backup Schedule',
		[BackupSchedule]::description,
		"Enter cron expression (e.g., $([BackupSchedule]::default))") {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([BackupSchedule]::default))"
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.backupScheduleCronExpression = ([Question]$question).GetResponse([BackupSchedule]::default)
		return $true
	}

	[bool]CanRun() {
		return $this.config.IsUsingVelero()
	}

	[void]Reset(){
		$this.config.backupScheduleCronExpression = ''
	}
}

class BackupDatabaseTimeout : Step {

	static [string] hidden $description = @'
Specify the timeout in minutes for the database backup to complete. The 
database backup runs as a Velero pre exec hook. The timeout determines how 
long Velero will wait for the database backup command to finish running. 

Note: Press Enter to use the default timeout value.
'@

	static [string] hidden $default = '30'

	BackupDatabaseTimeout([ConfigInput] $config) : base(
		[BackupDatabaseTimeout].Name, 
		$config,
		'Backup Database Timeout',
		[BackupDatabaseTimeout]::description,
		"Enter timeout in minutes (e.g., $([BackupDatabaseTimeout]::default))") {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([BackupDatabaseTimeout]::default))"
		$question.validationExpr = '^[1-9]\d*$'
		$question.validationHelp = "You entered an invalid value. Enter a value in minutes such as $([BackupDatabaseTimeout]::default)"
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.backupDatabaseTimeoutMinutes = ([Question]$question).GetResponse([BackupDatabaseTimeout]::default)
		return $true
	}

	[bool]CanRun() {
		return $this.config.IsUsingVelero()
	}

	[void]Reset(){
		$this.config.backupDatabaseTimeoutMinutes = 0
	}
}

class BackupTimeToLive : Step {

	static [string] hidden $description = @'
Specify the duration in hours to protect a backup from deletion. Once a backup 
has expired, it is eligible for deletion. 

Note: Press Enter to use the default time to live value.
'@

	static [string] hidden $default = '720'

	BackupTimeToLive([ConfigInput] $config) : base(
		[BackupTimeToLive].Name, 
		$config,
		'Backup Time to Live',
		[BackupTimeToLive]::description,
		"Enter timeout in minutes (e.g., $([BackupTimeToLive]::default))") {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		$question.emptyResponseLabel = "Accept default ($([BackupTimeToLive]::default))"
		$question.validationExpr = '^[1-9]\d*$'
		$question.validationHelp = "You entered an invalid value. Enter a value in minutes such as $([BackupTimeToLive]::default)"
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.backupTimeToLiveHours = ([Question]$question).GetResponse([BackupTimeToLive]::default)
		return $true
	}

	[bool]CanRun() {
		return $this.config.IsUsingVelero()
	}

	[void]Reset(){
		$this.config.backupTimeToLiveHours = 0
	}
}
