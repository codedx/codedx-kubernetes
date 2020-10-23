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
instructions.

Code Dx has been tested with Velero 1.3, 1.4, and 1.5.

If you choose to use Velero, the setup script will create a new Schedule 
resource. You can use the admin/set-backup.ps1 script to change the schedule 
configuration. Refer to the following URL for more information:

https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/config/backup-restore.md
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
			[tuple]::create('Velero (&Restic)', 'Use Velero''s Restic integration')), 1)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$multipleChoiceQuestion = ([MultipleChoiceQuestion]$question)
		switch ($multipleChoiceQuestion.choice) {
			0 { $this.config.backupType = '' }
			1 { $this.config.backupType = 'Velero' }
			2 { $this.config.backupType = 'Velero-Restic' }
		}
		return $true
	}

	[void]Reset(){
		$this.config.backupType = ''
	}
}
