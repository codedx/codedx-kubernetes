'./step.ps1',
'../core/common/input.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class IngressKind : Step {

	static [string] hidden $description = @'
Specify the the type of ingress you want to use. If you select the 'NGINX and 
Cert Manager with Let's Encrypt' option, you will install the Let's Encrypt 
Cert Manager. You should not run more than one copy of Cert Manager on your 
cluster.
'@

	IngressKind([ConfigInput] $config) : base(
		[IngressKind].Name, 
		$config,
		'Ingress Type',
		[IngressKind]::description,
		'What type of ingress do you want to use?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$choices = `
			[tuple]::create('None', 'Do not configure any type of ingress (use port-forward or something else to access Code Dx)'),
			[tuple]::create('NGINX and &Let''s Encrypt', 'Install and use NGINX with Let''s Encrypt Cert Manager'),
			[tuple]::create('Load Balancer', 'Configure the Code Dx Kubernetes service as a LoadBalancer service type'),
			[tuple]::create('External Ingress Controller', 'Create ingress resource for use with your ingress controller'),
			[tuple]::create('External NGINX Ingress Controller', 'Create ingress resource for use with your NGINX ingress controller')

		if ($this.config.k8sProvider -eq [ProviderType]::Eks) {
			$choices += [tuple]::create('AWS &Classic Load Balancer with Certificate Manager', 'Use AWS Classic Load Balancer')
			$choices += [tuple]::create('AWS &Network Load Balancer with Certificate Manager', 'Use AWS Network Load Balancer')
		}

		return new-object MultipleChoiceQuestion($prompt, $choices, -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		switch (([MultipleChoiceQuestion]$question).choice) {
			0 { $this.config.ingressType = [IngressType]::None }
			1 { $this.config.ingressType = [IngressType]::NginxLetsEncrypt }
			2 { $this.config.ingressType = [IngressType]::LoadBalancer }
			3 { $this.config.ingressType = [IngressType]::ExternalIngressController }
			4 { $this.config.ingressType = [IngressType]::ExternalNginxIngressController }
			5 { $this.config.ingressType = [IngressType]::ClassicElb }
			6 { $this.config.ingressType = [IngressType]::NetworkElb }
		}

		$this.config.skipNginxIngressControllerInstall = $this.config.ingressType -ne [IngressType]::NginxLetsEncrypt
		$this.config.skipLetsEncryptCertManagerInstall = $this.config.skipNginxIngressControllerInstall

		$this.config.skipIngressEnabled = $this.config.skipNginxIngressControllerInstall -and $this.config.ingressType -ne [IngressType]::ExternalIngressController -and $this.config.ingressType -ne [IngressType]::ExternalNginxIngressController
		$this.config.skipIngressAssumesNginx = $this.config.skipNginxIngressControllerInstall -and $this.config.ingressType -ne [IngressType]::ExternalNginxIngressController
		
		$this.config.ingressAnnotationsCodeDx = @{}
		$this.config.serviceTypeCodeDx = ($this.config.ingressType -eq [IngressType]::LoadBalancer -or $this.config.ingressType -eq [IngressType]::ClassicElb -or $this.config.ingressType -eq [IngressType]::NetworkElb) ? 'LoadBalancer' : ''
		
		if ($this.config.ingressType -eq [IngressType]::ClassicElb -or $this.config.ingressType -eq [IngressType]::NetworkElb) {
			$this.config.codeDxTlsServicePortNumber = 443
		}
		
		return $true
	}

	[void]Reset(){
		$this.config.skipNginxIngressControllerInstall = $false
		$this.config.skipLetsEncryptCertManagerInstall = $false
		$this.config.skipIngressEnabled = $false
		$this.config.skipIngressAssumesNginx = $false
		$this.config.ingressAnnotationsCodeDx = @{}
		$this.config.serviceTypeCodeDx = ''
		$this.config.codeDxTlsServicePortNumber = [ConfigInput]::codeDxTlsServicePortNumberDefault
	}
}

class NginxIngressNamespace : Step {

	static [string] hidden $description = @'
Specify the Kubernetes namespace where Nginx components will be installed. 
For example, to install components in a namespace named 'nginx', enter  
that name here. The namespace will be created if it does not already exist.
'@

	NginxIngressNamespace([ConfigInput] $config) : base(
		[NginxIngressNamespace].Name, 
		$config,
		'NGINX Namespace',
		[NginxIngressNamespace]::description,
		'Enter namespace') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.nginxIngressControllerNamespace = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.nginxIngressControllerNamespace = 'nginx'
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt
	}
}

class NginxIngressAddress : Step {

	static [string] hidden $description = @'
Specify an existing IP address to associate with the Code Dx ingress resource.
'@

	NginxIngressAddress([ConfigInput] $config) : base(
		[NginxIngressAddress].Name, 
		$config,
		'NGINX Ingress IP Address',
		[NginxIngressAddress]::description,
		'Enter IP address') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		$question = new-object Question('Enter IP address')
		$question.validationExpr = '^(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)\.(25[0-5]|2[0-4][0-9]|[01]?[0-9][0-9]?)$'
		return $question
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.nginxIngressControllerLoadBalancerIP = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.nginxIngressControllerLoadBalancerIP = ''
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt -and $this.config.k8sProvider -eq [ProviderType]::Aks
	}
}

class LetsEncryptNamespace : Step {

	static [string] hidden $description = @'
Specify the Kubernetes namespace where the Let's Encrypt components will be 
installed. For example, to install components in a namespace named 'nginx', 
enter that name here. The namespace will be created if it does not 
already exist.
'@

	LetsEncryptNamespace([ConfigInput] $config) : base(
		[LetsEncryptNamespace].Name, 
		$config,
		'Let''s Encrypt Namespace',
		[LetsEncryptNamespace]::description,
		'Enter the Let''s Encrypt k8s namespace') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.letsEncryptCertManagerNamespace = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.letsEncryptCertManagerNamespace = 'cert-manager'
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt
	}
}

class LetsEncryptClusterIssuer : Step {

	static [string] hidden $description = @'
Specify the name of the Let's Encrypt Cluster Issuer you want to use. The 
setup script will create two Cluster Issuer resources, one for staging and 
one for production use.

The staging configuration will be generated as a ClusterIssuer resource named 
letsencrypt-staging, and the production issuer will be named letsencrypt-prod. 
Use the staging version first. When everything is working correctly, run the 
setup again replacing the letsencrypt-staging parameter with letsencrypt-prod.
'@

	LetsEncryptClusterIssuer([ConfigInput] $config) : base(
		[LetsEncryptClusterIssuer].Name, 
		$config,
		'Let''s Encrypt Cluster Issuer',
		[LetsEncryptClusterIssuer]::description,
		'Do you want to use the staging cluster issuer for Let''s Encrypt?') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object YesNoQuestion($prompt, 
			'Yes, use the letsencrypt-staging issuer.', 
			'No, use the letsencrypt-prod issuer.', -1)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.letsEncryptCertManagerClusterIssuer = ([YesNoQuestion]$question).choice -eq 0 ? 'letsencrypt-staging' : 'letsencrypt-prod'
		return $true
	}

	[void]Reset(){
		$this.config.letsEncryptCertManagerNamespace = 'letsencrypt-staging'
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt
	}
}

class LetsEncryptEmail : Step {

	static [string] hidden $description = @'
Specify an email address to associate with the Let's Encrypt registration.
'@

	LetsEncryptEmail([ConfigInput] $config) : base(
		[LetsEncryptEmail].Name, 
		$config,
		'Let''s Encrypt Email Contact',
		[LetsEncryptEmail]::description,
		'Enter your registration email address') {}

	[IQuestion]MakeQuestion([string] $prompt) {
		return new-object EmailAddressQuestion($prompt, $false)
	}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.letsEncryptCertManagerRegistrationEmailAddress = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.letsEncryptCertManagerRegistrationEmailAddress = ''
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxLetsEncrypt
	}
}

class IngressCertificateArn : Step {

	static [string] hidden $description = @'
Specify the Amazon Resource Name (ARN) for the certificate you want to use 
with the Code Dx EKS service. You can create a new certificate using the
AWS Certificates console.
'@

	IngressCertificateArn([ConfigInput] $config) : base(
		[IngressCertificateArn].Name, 
		$config,
		'AWS Certificate ARN',
		[IngressCertificateArn]::description,
		'Enter your certificate ARN') {}

	[bool]HandleResponse([IQuestion] $question) {
		
		$certArn = ([Question]$question).response

		$protocol = $this.config.skipTLS ? 'http' : 'https'
		$this.config.serviceAnnotationsCodeDx = @{
			'service.beta.kubernetes.io/aws-load-balancer-backend-protocol' = $protocol
    		'service.beta.kubernetes.io/aws-load-balancer-ssl-ports' = 'https'
    		'service.beta.kubernetes.io/aws-load-balancer-ssl-cert' = $certArn
		}
		if ($this.config.ingressType -eq [IngressType]::NetworkElb) {
			$this.config.serviceAnnotationsCodeDx['service.beta.kubernetes.io/aws-load-balancer-type'] = 'nlb'
		}
		return $true
	}

	[void]Reset(){
		$this.config.serviceAnnotationsCodeDx = @{}
	}

	[bool]CanRun() {
		return ($this.config.ingressType -eq [IngressType]::ClassicElb -or $this.config.ingressType -eq [IngressType]::NetworkElb)
	}
}

class DnsName : Step {

	static [string] hidden $description = @'
Specify the DNS name to associate with the Code Dx web application. This can 
be the hostname in lowercase letters when running on minikube or the server 
name of a host you will access over the network using a DNS registration.
'@

	DnsName([ConfigInput] $config) : base(
		[DnsName].Name, 
		$config,
		'Code Dx DNS Name',
		[DnsName]::description,
		'Enter DNS name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.codeDxDnsName = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.codeDxDnsName = ''
	}

	[bool]CanRun() {
		return -not $this.config.skipIngressEnabled
	}
}
