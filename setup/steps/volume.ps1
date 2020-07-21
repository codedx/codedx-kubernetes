'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class DefaultVolumeSize : Step {

	static [string] hidden $description = @'
Specify whether you want to use the recommended volume sizes displayed 
below. You can specify each volume size individually by responding with 
the No option.
'@

	static [string] hidden $subordinateDatabaseDescription = @'
Note: Subordinate database containers use two volumes, the main database 
volume and a volume to store backup files. The default volume size for the 
subordinate database specified here applies to *each* volume. For example, 
specifying 64 means creating two 64 GiB volumes.
'@

	DefaultVolumeSize([ConfigInput] $config) : base(
		[DefaultVolumeSize].Name, 
		$config,
		'Volume Sizes',
		[DefaultVolumeSize]::description,
		'Use default volume sizes?') { }

	[IQuestion] MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, do not specify sizes for each volume',
			'No, specify a size for each volume', 0)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$applyDefaults = ([YesNoQuestion]$question).choice -eq 0
		if ($applyDefaults) {
			$this.GetSteps() | ForEach-Object {
				$_.ApplyDefault()
			}
		}
		$this.config.useVolumeSizeDefaults = $applyDefaults
		return $true
	}

	[void]Reset() {
		$this.config.useVolumeSizeDefaults = $false
	}

	[Step[]] GetSteps() {

		$steps = @()
		[CodeDxVolumeSize],[MasterDatabaseVolumeSize],[SubordinateDatabaseVolumeSize],[MinIOVolumeSize] | ForEach-Object {
			$step = new-object -type $_ -args $this.config
			if ($step.CanRun()) {
				$steps += $step
			}
		}
		return $steps
	}

	[string]GetMessage() {

		$message = [DefaultVolumeSize]::description
		$message += "`n`nHere are the defaults:`n`n"
		$steps = $this.GetSteps()
		$steps | ForEach-Object {
			$default = $_.GetDefault()
			if ('' -ne $default) {
				$message += "    {0}: {1}`n" -f (([VolumeSizeStep]$_).title,$default)
			}
		}

		if (($steps | ForEach-Object { $_.Name }) -contains [SubordinateDatabaseVolumeSize].Name) {
			$message += "`n`n"
			$message += [DefaultVolumeSize]::subordinateDatabaseDescription
		}

		return $message
	}
}

class VolumeSizeStep : Step {

	static [string] hidden $description = @'
Specify the amount of volume storage in gibibytes.
'@

	VolumeSizeStep([string] $name, 
		[string] $title, 
		[ConfigInput] $config) : base($name, 
			$config,
			$title,
			[VolumeSizeStep]::description,
			'Enter volume size (e.g., 64)') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object IntegerQuestion($prompt, 1, [int]::MaxValue, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.HandleSizeResponse(([IntegerQuestion]$question).intResponse)
		return $true
	}

	[void]HandleSizeResponse([int] $size) {
		throw [NotImplementedException]
	}

	[bool]CanRun() {
		return -not $this.config.useVolumeSizeDefaults
	}
}

class CodeDxVolumeSize : VolumeSizeStep {

	CodeDxVolumeSize([ConfigInput] $config) : base([CodeDxVolumeSize].Name, 'Code Dx Volume Size', $config) {}

	[void]HandleSizeResponse([int] $size) {
		$this.config.codeDxVolumeSizeGiB = $size
	}
	
	[void]Reset() {
		$this.config.codeDxVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
	}

	[void]ApplyDefault() {
		$this.config.codeDxVolumeSizeGiB = $this.GetDefault()
	}

	[string]GetDefault() {
		return '64'
	}
}

class MasterDatabaseVolumeSize : VolumeSizeStep {

	MasterDatabaseVolumeSize([ConfigInput] $config) : base([MasterDatabaseVolumeSize].Name, 'Master Database Volume Size', $config) {}

	[void]HandleSizeResponse([int] $size) {
		$this.config.dbVolumeSizeGiB = $size
	}

	[void]Reset() {
		$this.config.dbVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
	}

	[bool]CanRun() {
		return ([VolumeSizeStep]$this).CanRun() -and (-not ($this.config.skipDatabase))
	}

	[void]ApplyDefault() {
		$this.config.dbVolumeSizeGiB = $this.GetDefault()
	}

	[string]GetDefault() {
		return '64'
	}
}

class SubordinateDatabaseVolumeSize : VolumeSizeStep {

	static [string] hidden $description = @'
Subordinate database containers use two volumes, the main database volume 
and a volume to store backup files. The volume size specified here applies to 
*each* volume. For example, specifying 64 means creating two 64 GiB volumes.
'@

	SubordinateDatabaseVolumeSize([ConfigInput] $config) : base([SubordinateDatabaseVolumeSize].Name, 'Subordinate Database Volume Size', $config) {}

	[void]HandleSizeResponse([int] $size) {
		$this.config.dbSlaveVolumeSizeGiB = $size
	}

	[void]Reset() {
		$this.config.codeDxVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
	}

	[bool]CanRun() {
		return ([VolumeSizeStep]$this).CanRun() -and (-not ($this.config.skipDatabase)) -and $this.config.dbSlaveReplicaCount -gt 0
	}

	[void]ApplyDefault() {
		$this.config.dbSlaveVolumeSizeGiB = $this.GetDefault()
	}

	[string]GetDefault() {
		return '64'
	}

	[string]GetMessage() {

		$message = [VolumeSizeStep]::description
		$message += "`n`n"
		$message += [SubordinateDatabaseVolumeSize]::description
		return $message
	}
}

class MinIOVolumeSize : VolumeSizeStep {

	MinIOVolumeSize([ConfigInput] $config) : base([MinIOVolumeSize].Name, 'MinIO Volume Size', $config) {}

	[void]HandleSizeResponse([int] $size) {
		$this.config.minioVolumeSizeGiB = $size
	}

	[void]Reset() {
		$this.config.codeDxVolumeSizeGiB = [ConfigInput]::volumeSizeGiBDefault
	}

	[bool]CanRun() {
		return ([VolumeSizeStep]$this).CanRun() -and (-not ($this.config.skipToolOrchestration))
	}

	[void]ApplyDefault() {
		$this.config.minioVolumeSizeGiB = $this.GetDefault()
	}

	[string]GetDefault() {
		return '64'
	}
}

class StorageClassName : Step {

	static [string] hidden $description = @'
Specify a specific storage class that already exists on your Kubernetes 
cluster or press Enter to accept your cluster's default storage class. 

Note: Using a storage class associated with high speed storage (e.g., SSD) 
is recommended.
'@

	StorageClassName([ConfigInput] $config) : base(
		[StorageClassName].Name, 
		$config,
		'Storage Class Name',
		[StorageClassName]::description,
		'Enter storage provider') { }

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.storageClassName = ([Question]$question).response
		return $true
	}

	[void]Reset() {
		$this.config.storageClassName = ''
	}
}
