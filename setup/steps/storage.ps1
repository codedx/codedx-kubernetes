'./step.ps1'
'../core/common/codedx.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class UseExternalStorage : Step {

	static [string] hidden $description = @'
Code Dx orchestrated analyses depend on an object storage system. You 
can use any storage system that supports an AWS S3-compliant API (e.g., 
AWS, GCP, MinIO, etc.). Alternatively, the Code Dx deployment includes 
an older MinIO version that you can use.
'@

	UseExternalStorage([ConfigInput] $config) : base(
		[UseExternalStorage].Name, 
		$config,
		'Orchestrated Analysis Storage',
		[UseExternalStorage]::description,
		'Do you want to use an external object storage system you provide?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, I want to use an object storage system that I will provide', 
			'No, I want to use an object storage system that Code Dx deploys on Kubernetes', 1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.skipMinIO = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.skipMinIO = $false
	}

	[bool]CanRun() {
		return -not $this.config.skipToolOrchestration
	}
}

class ExternalStorageEndpoint : Step {

	static [string] hidden $description = @'
Specify the endpoint for your object storage system. Your endpoint should
include a hostname and an optional port.

An AWS S3 endpoint might look like 's3-us-east-2.amazonaws.com' and a MinIO
endpoint might look like 'my-minio-hostname:9000'.
'@

	ExternalStorageEndpoint([ConfigInput] $config) : base(
		[ExternalStorageEndpoint].Name, 
		$config,
		'Orchestrated Analysis Storage Endpoint',
		[ExternalStorageEndpoint]::description,
		'Enter your external object storage endpoint') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStorageEndpoint = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalWorkflowStorageEndpoint = ''
	}

	[bool]CanRun() {
		return $this.config.skipMinIO
	}
}

class ExternalStorageTLS : Step {

	static [string] hidden $description = @'
Specify whether your object storage system is accessible via a secure 
connection protected by TLS.
'@

	ExternalStorageTLS([ConfigInput] $config) : base(
		[ExternalStorageTLS].Name, 
		$config,
		'Orchestrated Analysis Storage Endpoint Security',
		[ExternalStorageTLS]::description,
		'Is your object storage system connection secure?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, my object storage system connection is secure (i.e., uses TLS)', 
			'No, my object storage system is not secure', 0)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStorageEndpointSecure = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.externalWorkflowStorageEndpointSecure = $false
	}

	[bool]CanRun() {
		return $this.config.skipMinIO
	}
}

class ExternalStorageUsername : Step {

	static [string] hidden $description = @'
Specify the username of the account that will connect to your object 
storage system. The account must have read/write permissions to a
storage bucket you will specify later. If the bucket does not exist,
the account should have permission to create that bucket.
'@

	ExternalStorageUsername([ConfigInput] $config) : base(
		[ExternalStorageUsername].Name, 
		$config,
		'Orchestrated Analysis Storage Username',
		[ExternalStorageUsername]::description,
		'Enter your external object storage username') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStorageUsername = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalWorkflowStorageUsername = ''
	}

	[bool]CanRun() {
		return $this.config.skipMinIO
	}
}

class ExternalStoragePassword : Step {

	static [string] hidden $description = @'
Specify the password of the account that will connect to your object 
storage system. The account must have read/write permissions to a
storage bucket you will specify later. If the bucket does not exist,
the account should have permission to create that bucket.
'@

	ExternalStoragePassword([ConfigInput] $config) : base(
		[ExternalStoragePassword].Name, 
		$config,
		'Orchestrated Analysis Storage Password',
		[ExternalStoragePassword]::description,
		'Enter your external object storage password') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object ConfirmationQuestion($prompt)
		$question.isSecure = $true
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStoragePwd = ([ConfirmationQuestion]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalWorkflowStoragePwd = ''
	}

	[bool]CanRun() {
		return $this.config.skipMinIO
	}
}

class ExternalStorageBucket : Step {

	static [string] hidden $description = @'
Specify the name of the object storage bucket where Code Dx will store
orchestrated analysis data. If this bucket does not exist, Code Dx
will attempt to create the bucket using the object storage system
credential you specified.
'@

	ExternalStorageBucket([ConfigInput] $config) : base(
		[ExternalStorageBucket].Name, 
		$config,
		'Orchestrated Analysis Storage Bucket',
		[ExternalStorageBucket]::description,
		'Enter the name of your object storage bucket') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStorageBucketName = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.externalWorkflowStorageBucketName = ''
	}

	[bool]CanRun() {
		return $this.config.skipMinIO
	}
}

class ExternalStorageTrustCert : Step {

	static [string] hidden $description = @'
Specify whether your object storage system endpoint uses a certificate
not issued by a well-known certificate authority. If so, you will need
to specify a file that includes the endpoint's certificate chain.
'@

	ExternalStorageTrustCert([ConfigInput] $config) : base(
		[ExternalStorageTrustCert].Name, 
		$config,
		'Orchestrated Analysis Storage Trust',
		[ExternalStorageTrustCert]::description,
		'Do you need to provide your endpoint''s certificate chain?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, my object storage system uses a certificate not issued by a well-known CA', 
			'No, my object storage system uses a certificate issued by a well-known CA', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStorageTrustCert = ([YesNoQuestion]$question).choice -eq 0
		return $true
	}

	[void]Reset(){
		$this.config.externalWorkflowStorageTrustCert = $false
	}

	[bool]CanRun() {
		return $this.config.skipMinIO -and $this.config.externalWorkflowStorageEndpointSecure 
	}
}

class ExternalStorageCertificate : Step {

	static [string] hidden $description = @'
Specify a path to the certificate file for your object storage system endpoint.
The file should include the entire certificate chain.
'@

	ExternalStorageCertificate([ConfigInput] $config) : base(
		[ExternalStorageCertificate].Name,
		$config,
		'Orchestrated Analysis Storage Certificate',
		[ExternalStorageCertificate]::description,
		'Enter a certificate path') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object CertificateFileQuestion($prompt, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.externalWorkflowStorageCertChainPath = ([Question]$question).response
		return $true
	}

	[bool]CanRun() {
		return $this.config.skipMinIO -and $this.config.externalWorkflowStorageTrustCert 
	}

	[void]Reset(){
		$this.config.externalWorkflowStorageCertChainPath = ''
	}
}