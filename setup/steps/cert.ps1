
'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseDefaultCACerts : Step {

	static [string] hidden $description = @'
Specify whether you want to use the default Java cacerts file. Code Dx uses a
Java cacerts file to trust secure connections made to third-party applications
such as JIRA, Git, and other tools.

If you want to change the default password for the Java cacerts file or plan
to make connections to tools or endpoints (like LDAPS) that use self-signed
certificates or certificates not issued by a well-known certificate authority,
you should answer No.
'@

	UseDefaultCACerts([ConfigInput] $config) : base(
		[UseDefaultCACerts].Name,
		$config,
		'Default Java cacerts',
		[UseDefaultCACerts]::description,
		'Do you want to use the default cacerts file?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, use the default cacerts file.',
			'No, I will specify a path to the cacerts file I want to use.', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useDefaultCACerts = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[bool]CanRun() {
		return (-not $this.config.skipDatabase -or $this.config.externalDatabaseSkipTls) -and
			(-not $this.config.UseFluxGitOps() -or $this.config.skipTLS)
	}

	[void]Reset(){
		$this.config.useDefaultCACerts = $false
	}
}

class CACertsFile : Step {

	static [string] hidden $description = @'
Specify the path to your Java cacerts file. You can find the cacerts file
under your Java installation. Use of a cacerts file from a Java 8 JRE 
install is strongly recommended.

Note: You can find a cacerts file in the jre/lib/security directory under
your Java installation directory. On Linux, you can follow the symbolic
link for your java file to locate your Java home directory and cacerts
(e.g., /usr/local/openjdk-8/jre/lib/security).
'@

	CACertsFile([ConfigInput] $config) : base(
		[CACertsFile].Name,
		$config,
		'Java cacerts File Path',
		[CACertsFile]::description,
		'Enter the path to your cacerts file') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object PathQuestion($prompt,	[microsoft.powershell.commands.testpathtype]::Leaf, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.caCertsFilePath = ([PathQuestion]$question).response
		return $true
	}

	[bool]CanRun() {
		return -not $this.config.useDefaultCACerts -or 
			($this.config.skipDatabase -and -not $this.config.externalDatabaseSkipTls) -or
			($this.config.UseFluxGitOps() -and (-not $this.config.skipTLS))
	}

	[void]Reset(){
		$this.config.caCertsFilePath = ''
	}
}

class CACertsFilePassword : Step {

	static [string] hidden $description = @'
Specify the password to your Java cacerts file. If you have not set a
password, use the default Java cacerts file password (changeit).
'@

	CACertsFilePassword([ConfigInput] $config) : base(
		[CACertsFilePassword].Name,
		$config,
		'Java cacerts File Password',
		[CACertsFilePassword]::description,
		'Enter the password for your cacerts file') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.isSecure = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {

		$pwd = ([Question]$question).response

		if (-not (Test-KeystorePassword $this.config.caCertsFilePath $pwd)) {
			Write-Host "The password you entered is invalid for $($this.config.caCertsFilePath)."
			Write-Host "Enter a different password or go back and choose a different cacerts file."
			return $false
		}

		$this.config.caCertsFilePwd = $pwd
		return $true
	}

	[void]Reset(){
		$this.config.caCertsFilePwd = ''
	}
}

class CACertsChangePassword : Step {

	static [string] hidden $description = @'
Specify whether you want to change the password of the Java cacerts file.
'@

	CACertsChangePassword([ConfigInput] $config) : base(
		[CACertsChangePassword].Name,
		$config,
		'Java cacerts File Change Password',
		[CACertsChangePassword]::description,
		'Do you want to change the cacerts file password?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to change the password.',
			'No, I do not want to change the password.', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.useNewCACertsFilePwd = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.useNewCACertsFilePwd = $false
	}
}

class CACertsFileNewPassword : Step {

	static [string] hidden $description = @'
Specify the new password for your Java cacerts file.
'@

	CACertsFileNewPassword([ConfigInput] $config) : base(
		[CACertsFileNewPassword].Name,
		$config,
		'Java cacerts File New Password',
		[CACertsFileNewPassword]::description,
		'Enter the new password for your cacerts file') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.minimumLength = 6
		$question.blacklist = @("'")
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {

		$this.config.caCertsFileNewPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[bool]CanRun() {
		return $this.config.useNewCACertsFilePwd
	}

	[void]Reset(){
		$this.config.caCertsFileNewPwd = ''
	}
}

class AddExtraCertificates : Step {

	static [string] hidden $description = @'
Code Dx uses a Java cacerts file to trust secure connections made to
third-party applications.

If you want to plan to make connections to tools that use self-signed
certificates or certificates not issued by a well-known certificate authority,
you can add the certificates that Code Dx should trust.
'@

	AddExtraCertificates([ConfigInput] $config) : base(
		[AddExtraCertificates].Name,
		$config,
		'Add Extra Certificates',
		[AddExtraCertificates]::description,
		'Do you want to add extra certificates to trust?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt,
			'Yes, I want to add extra certificates for Code Dx to trust.',
			'No, I do not want to add any extra certificates for Code Dx to trust.', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.addExtraCertificates = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.addExtraCertificates = $false
	}
}

class ExtraCertificates : Step {

	static [string] hidden $description = @'
Specify each certificate file you want to add. Press Enter at the prompt when
you have finished adding certificates.
'@

	ExtraCertificates([ConfigInput] $config) : base(
		[ExtraCertificates].Name,
		$config,
		'Extra Certificate Files',
		[ExtraCertificates]::description,
		'Enter a certificate file') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object CertificateFileQuestion($prompt, $false)
	}

	[bool]Run() {

		Write-HostSection $this.title ($this.GetMessage())

		$files = @()
		while ($true) {
			$question = $this.MakeQuestion($this.prompt)
			$question.allowEmptyResponse = $files.count -gt 0
			if ($question.allowEmptyResponse) {
				$question.emptyResponseLabel = 'Done'
				$question.emptyResponseHelp = 'I finished entering certificate files'
			}
			$question.Prompt()

			if (-not $question.hasResponse) {
				return $false
			}

			if ($question.isResponseEmpty) {
				break
			}
			$files += $question.response
		}

		$this.config.extraCodeDxTrustedCaCertPaths = $files
		return $true
	}

	[bool]HandleResponse([IQuestion] $question) {
		return $true
	}

	[bool]CanRun() {
		return $this.config.addExtraCertificates
	}

	[void]Reset(){
		$this.config.extraCodeDxTrustedCaCertPaths = @()
	}
}
