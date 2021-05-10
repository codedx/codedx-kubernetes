'./step.ps1',
'../core/common/input.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class AuthenticationType : Step {

	static [string] hidden $description = @'
By default, Code Dx users log on using a local account by specifying a 
username and password. Code Dx can also be configured to authenticate users 
against a SAML 2.0 Identity Provider (IdP) or an LDAP directory.
'@

	AuthenticationType([ConfigInput] $config) : base(
		[AuthenticationType].Name, 
		$config,
		'Authentication Type',
		[AuthenticationType]::description,
		'How will users authenticate to Code Dx?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, @(
			[tuple]::create('&Local Accounts', 'Use local Code Dx accounts only'),
			[tuple]::create('&SAML', 'Use local Code Dx accounts and a SAML IdP'),
			[tuple]::create('L&DAP', 'Use local Code Dx accounts and an LDAP directory')), -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$multipleChoiceQuestion = ([MultipleChoiceQuestion]$question)
		$this.config.useSaml = $multipleChoiceQuestion.choice -eq 1
		$this.config.useLdap = $multipleChoiceQuestion.choice -eq 2
		return $true
	}

	[void]Reset(){
		$this.config.useSaml = $false
		$this.config.useLdap = $false
	}
}

class LdapInstructions : Step {
	static [string] hidden $description = @'
Code Dx supports authentication against an LDAP directory, but you must 
manually configure LDAP.

Refer to the following URL for LDAP configuration instructions. Read the 
instructions at this time and remember to add any necessary certificates 
if you plan to use LDAPS:


'@

	static [string] hidden $nonGitOpsUrl = 'https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/auth/use-ldap.md'
	static [string] hidden $gitOpsUrl = 'https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/auth/use-ldap-gitops.md'

	LdapInstructions([ConfigInput] $config) : base(
		[LdapInstructions].Name, 
		$config,
		'LDAP Authentication',
		[LdapInstructions]::description,
		'Do you want to continue?') {}

	[string]GetMessage() {

		$message = [LdapInstructions]::description
		if ($this.config.UseFluxGitOps()) {
			$message += [LdapInstructions]::gitOpsUrl
		} else {
			$message += [LdapInstructions]::nonGitOpsUrl
		}
		return $message
	}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, 
			[tuple]::create('&Yes', 'Yes, I will manually configure LDAP later on'),
			-1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		return $true
	}

	[bool]CanRun() {
		return $this.config.useLdap
	}
}

class SamlAuthenticationDnsName : Step {
	
	static [string] hidden $description = @'
Specify the DNS name to associate with the Code Dx web application. The SAML 
IdP will connect to your Code Dx instance using the Code Dx Assertion Consumer 
Service (ACS) endpoint, which will be a URL that is based on your Code Dx DNS 
name.
'@

	SamlAuthenticationDnsName([ConfigInput] $config) : base(
		[SamlAuthenticationDnsName].Name, 
		$config,
		'Code Dx DNS Name',
		[SamlAuthenticationDnsName]::description,
		'Enter DNS name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.codeDxDnsName = ([Question]$question).response
		$this.config.hostBasePath = "$($this.config.skipTLS ? 'http' : 'https')://$($this.config.codeDxDnsName)/codedx"
		return $true
	}

	[bool]CanRun() {
		return $this.config.useSaml -and [string]::isnullorempty($this.config.codeDxDnsName)
	}

	[void]Reset(){
		$this.config.codeDxDnsName = ''
		$this.config.hostBasePath = ''
	}
}

class SamlIdpMetadata : Step {

	static [string] hidden $description = @'
Specify the IdP metadata you downloaded from your SAML identity provider.
'@

	SamlIdpMetadata([ConfigInput] $config) : base(
		[SamlIdpMetadata].Name, 
		$config,
		'SAML Identity Provider Metadata',
		[SamlIdpMetadata]::description,
		'Enter IdP metadata path') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object PathQuestion($prompt,	[microsoft.powershell.commands.testpathtype]::Leaf, $false)
	}
	
	[bool]HandleResponse([IQuestion] $question) {
		$this.config.samlIdentityProviderMetadataPath = ([PathQuestion]$question).response
		return $true
	}

	[bool]CanRun() {
		return $this.config.useSaml
	}

	[void]Reset(){
		$this.config.samlIdentityProviderMetadataPath = ''
	}
}

class SamlAppName : Step {

	static [string] hidden $description = @'
Specify the application name or ID that was previously registered with your 
SAML identity provider and is associated with your Code Dx application.
'@

	SamlAppName([ConfigInput] $config) : base(
		[SamlAppName].Name, 
		$config,
		'SAML Application Name',
		[SamlAppName]::description,
		'Enter SAML client ID/name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.samlAppName = ([Question]$question).response
		return $true
	}

	[string]GetMessage() {

		$protocol = 'https'
		if ($this.config.skipTLS) {
			$protocol = 'http'
		}

		return $this.message + "`n`nYour Code Dx ACS endpoint will be $($this.config.hostBasePath)/login/callback/saml."
	}

	[bool]CanRun() {
		return $this.config.useSaml
	}

	[void]Reset(){
		$this.config.samlAppName = ''
	}
}

class SamlKeystorePwd : Step {

	static [string] hidden $description = @'
Specify the password to protect the keystore that Code Dx will create to store 
the key pair that Code Dx will use to connect to your SAML identify provider.
'@

	SamlKeystorePwd([ConfigInput] $config) : base(
		[SamlKeystorePwd].Name, 
		$config,
		'SAML Keystore Password',
		[SamlKeystorePwd]::description,
		'Enter SAML keystore password') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.minimumLength = 8
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.samlKeystorePwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[bool]CanRun() {
		return $this.config.useSaml
	}

	[void]Reset(){
		$this.config.samlKeystorePwd = ''
	}
}

class SamlPrivateKeyPwd : Step {

	static [string] hidden $description = @'
Specify the password to protect the private key of the key pair that Code Dx 
will use to connect to your SAML identify provider.
'@

	SamlPrivateKeyPwd([ConfigInput] $config) : base(
		[SamlPrivateKeyPwd].Name, 
		$config,
		'SAML Private Key Password',
		[SamlPrivateKeyPwd]::description,
		'Enter SAML private key password') {}

	[IQuestion] MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		$question.minimumLength = 8
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.samlPrivateKeyPwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[bool]CanRun() {
		return $this.config.useSaml
	}

	[void]Reset(){
		$this.config.samlPrivateKeyPwd = ''
	}
}

class SamlExtraConfig : Step {
	static [string] hidden $description = @'
The setup script will configure the following Code Dx SAML properties based on 
the information you have provided thus far:

- auth.saml2.identityProviderMetadataPath
- auth.saml2.entityId
- auth.saml2.keystorePassword
- auth.saml2.privateKeyPassword
- auth.hostBasePath

You can find the entire list of Code Dx SAML properties at 
https://codedx.com/Documentation/InstallGuide.html#SAMLConfiguration

To configure additional SAML properties, follow these instructions:
https://github.com/codedx/codedx-kubernetes/blob/master/setup/core/docs/auth/use-saml.md
'@

	SamlExtraConfig([ConfigInput] $config) : base(
		[SamlExtraConfig].Name, 
		$config,
		'SAML Extra Config',
		[SamlExtraConfig]::description,
		'Do you want to continue?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object MultipleChoiceQuestion($prompt, 
			[tuple]::create('&Yes', 'Yes, continue to the next step'),
			-1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		return $true
	}

	[bool]CanRun() {
		return $this.config.useSaml
	}
}
