'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class SealedSecretsNamespace : Step {

	static [string] hidden $description = @'
Specify the namespace where you installed Bitnami's Sealed Secrets.
'@

	SealedSecretsNamespace([ConfigInput] $config) : base(
		[SealedSecretsNamespace].Name, 
		$config,
		'Sealed Secrets Namespace',
		[SealedSecretsNamespace]::description,
		'Enter Sealed Secrets namespace name') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question($prompt)
		$question.allowEmptyResponse = $false
		$question.validationExpr = '^[a-z0-9]([-a-z0-9]*[a-z0-9])?(\.[a-z0-9]([-a-z0-9]*[a-z0-9])?)*$'
		$question.validationHelp = 'The Code Dx namespace must consist of lowercase alphanumeric characters or ''-'', and must start and end with an alphanumeric character'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.sealedSecretsNamespace = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.sealedSecretsNamespace = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipSealedSecrets
	}
}

class SealedSecretsControllerName : Step {

	static [string] hidden $description = @'
Specify the name of the Sealed Secrets controller you installed.
'@

	SealedSecretsControllerName([ConfigInput] $config) : base(
		[SealedSecretsControllerName].Name, 
		$config,
		'Sealed Secrets Controller Name',
		[SealedSecretsControllerName]::description,
		'Enter Sealed Secrets controller name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.sealedSecretsControllerName = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.sealedSecretsControllerName = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipSealedSecrets
	}
}

class SealedSecretsPublicKeyPath : Step {

	SealedSecretsPublicKeyPath([ConfigInput] $config) : base(
		[SealedSecretsPublicKeyPath].Name, 
		$config,
		'Sealed Secrets Cert',
		'',
		'Enter the file path for your Sealed Secrets public key') {}

	[string]GetMessage() {
		return @"
Specify the public key for your the Sealed Secrets deployment. You can fetch 
the public key from the sealed-secrets pod log. Look for the pod associated with:

Namespace: $($this.config.sealedSecretsNamespace)
Deployment: $($this.config.sealedSecretsControllerName)

Save the contents between and including the BEGIN and END certificate lines to 
a file named sealed-secrets.pem.
"@
	}

	[IQuestion]MakeQuestion([string] $prompt) {
		# Note: CertificateFileQuestion requires a cert with a DN, and the SealedSecrets cert
		# may not include a DN, so only test file existence.
		return new-object PathQuestion($prompt, [microsoft.powershell.commands.testpathtype]::Leaf, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.sealedSecretsPublicKeyPath = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.sealedSecretsPublicKeyPath = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipSealedSecrets
	}
}
