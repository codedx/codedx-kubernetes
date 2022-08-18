'./step.ps1' | ForEach-Object {
	Write-Debug "'$PSCommandPath' is including file '$_'"
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path | out-null
}

class IngressKind : Step {

	static [string] hidden $description = @'
Specify how you will access Code Dx running on your cluster.
'@

	static [string] hidden $openshiftDescription = @'


The Guided Setup does not include support for creating OpenShift routes. If 
you plan to use routes, configure your routes after installing Code Dx.
'@

	IngressKind([ConfigInput] $config) : base(
		[IngressKind].Name, 
		$config,
		'Ingress Type',
		[IngressKind]::description,
		'What type of ingress do you want to use?') {}

	[string]GetMessage() {

		$message = [IngressKind]::description

		if ($this.config.k8sProvider -eq [ProviderType]::OpenShift) {
			$message += [IngressKind]::openshiftDescription
		}
		return $message
	}

	[IQuestion]MakeQuestion([string] $prompt) {

		$choices = @(
			[tuple]::create('ClusterIP Service', 'Configure the Code Dx Kubernetes service as a ClusterIP service type (use port-forward or something else to access Code Dx)'),
			[tuple]::create('NodePort Service', 'Configure the Code Dx Kubernetes service as a NodePort service type'),
			[tuple]::create('LoadBalancer Service', 'Configure the Code Dx Kubernetes service as a LoadBalancer service type'),
			[tuple]::create('NGINX Ingress', 'Create an ingress resource for use with an NGINX ingress controller you installed separately')
		)

		if ($this.config.k8sProvider -eq [ProviderType]::Eks) {
			$choices += [tuple]::create('Classic ELB (HTTPS)', 'Use AWS Classic Load Balancer with Certificate Manager')
			$choices += [tuple]::create('Network ELB (HTTPS)', 'Use AWS Network Load Balancer with Certificate Manager')
			$choices += [tuple]::create('Internal Classic ELB (HTTPS)', 'Use Internal AWS Classic Load Balancer')
		}

		return new-object MultipleChoiceQuestion($prompt, $choices, -1)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$this.config.skipServiceTLS = $this.config.skipTLS # match to improve backward compatibility
		$this.config.skipIngressEnabled = $true
		$this.config.serviceTypeCodeDx = 'ClusterIP'

		switch (([MultipleChoiceQuestion]$question).choice) {
			0 { $this.config.ingressType = [IngressType]::ClusterIP }
			1 { $this.config.ingressType = [IngressType]::NodePort; $this.config.serviceTypeCodeDx = 'NodePort' }
			2 { $this.config.ingressType = [IngressType]::LoadBalancer; $this.config.serviceTypeCodeDx = 'LoadBalancer' }
			3 { $this.config.ingressType = [IngressType]::NginxIngress; $this.config.skipIngressEnabled = $false;  }
			4 { $this.config.ingressType = [IngressType]::ClassicElb; $this.config.serviceTypeCodeDx = 'LoadBalancer' }
			5 { $this.config.ingressType = [IngressType]::NetworkElb; $this.config.serviceTypeCodeDx = 'LoadBalancer' }
			6 { $this.config.ingressType = [IngressType]::InternalClassicElb; $this.config.serviceTypeCodeDx = 'LoadBalancer' }
		}

		$this.config.ingressAnnotationsCodeDx = @{}
		if ($this.config.IsElbIngress()) {
			# always use port 443 for AWS ELB provisioning (if skipTLS is false, service can be accessed w/o ELB via HTTP on 443)
			$this.config.skipServiceTLS = $false
			$this.config.codeDxTlsServicePortNumber = 443
		}

		if ($this.config.IsNGINXIngress()) {
			$this.config.ingressAnnotationsCodeDx['nginx.ingress.kubernetes.io/proxy-body-size'] = '0'
			$this.config.ingressAnnotationsCodeDx['nginx.ingress.kubernetes.io/proxy-read-timeout'] = '3600'

			$protocol = 'HTTPS'
			if ($this.config.skipTLS) {
				$protocol = 'HTTP'
			}
			$this.config.ingressAnnotationsCodeDx['nginx.ingress.kubernetes.io/backend-protocol'] = $protocol
		}

		return $true
	}

	[void]Reset(){
		$this.config.skipIngressEnabled = $false
		$this.config.ingressAnnotationsCodeDx = @{}
		$this.config.serviceTypeCodeDx = ''
		$this.config.codeDxTlsServicePortNumber = [ConfigInput]::codeDxTlsServicePortNumberDefault
		$this.config.ingressType = [IngressType]::ClusterIP
	}
}

class NginxTLS : Step {

	static [string] hidden $description = @'
Specify how you will configure HTTPS for your NGINX ingress.

Using the cert-manager option (e.g., Let's Encrypt ) requires an 
existing cert-manager deployment with a ClusterIssuer resource or 
Issuer resource in the Code Dx namespace. For more details, refer to 
this URL:

https://cert-manager.io/docs/configuration/

To use the External Kubernetes TLS Secret option, you must create 
a Kubernetes TLS Secret resource in the Code Dx namespace. For more 
details, refer to this URL:

https://kubernetes.io/docs/concepts/services-networking/ingress/#tls
'@

	NginxTLS([ConfigInput] $config) : base(
		[NginxTLS].Name, 
		$config,
		'NGINX Ingress TLS',
		[NginxTLS]::description,
		'How will you configure HTTPS for your NGINX ingress?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$choices = @(
			[tuple]::create('HTTPS (cert-manager)', 'Access Code Dx using HTTPS and an cert-manager issuer like Let''s Encrypt'),
			[tuple]::create('HTTPS (External Kubernetes TLS Secret)', 'Access Code Dx using HTTPS and an existing Kubernetes TLS secret')
		)

		return new-object MultipleChoiceQuestion($prompt, $choices, -1)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$choice = ([MultipleChoiceQuestion]$question).choice

		switch ($choice) {
			0 { $this.config.ingressType = [IngressType]::NginxCertManagerIngress }
			1 { $this.config.ingressType = [IngressType]::NginxExternalSecretIngress }
		}

		return $true
	}

	[void]Reset(){
		$this.config.ingressType = [IngressType]::NginxIngress
	}

	[bool]CanRun() {
		return $this.config.IsNGINXIngress()
	}
}

class NginxTLSSecretName : Step {

	static [string] hidden $description = @'
Specify the name of an existing Kubernetes TLS Secret resource to 
reference in the TLS section of your NGINX ingress.

For more details, refer to this URL:
https://kubernetes.io/docs/concepts/services-networking/ingress/#tls

The command to create the Kubernetes TLS Secret resource will look like this:
kubectl -n cdx-namespace create secret tls name --cert=cert.pem --key=key.pem

Note: Your Kubernetes TLS Secret resource must already exist in the
Code Dx namespace. Otherwise, the ingress controller may use a 
fake/invalid certificate. 
'@

	NginxTLSSecretName([ConfigInput] $config) : base(
		[NginxTLSSecretName].Name,
		$config,
		'NGINX Ingress TLS Secret Name',
		[NginxTLSSecretName]::description,
		'Enter the name of your existing Kubernetes TLS Secret name') {}

	[bool]HandleResponse([IQuestion] $question) {
		$this.config.ingressTlsSecretNameCodeDx = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.ingressTlsSecretNameCodeDx = ''
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxExternalSecretIngress
	}
}

class CertManagerIssuerType : Step {

	static [string] hidden $description = @'
Specify whether you plan to use a cert-manager ClusterIssuer or Issuer 
resource.

A ClusterIssuer has cluster-wide scope. An Issuer resource must exist in
the Code Dx namespace you plan to use. If necessary, create the Code Dx 
namespace now so that you can create your Issuer resource.
'@

	CertManagerIssuerType([ConfigInput] $config) : base(
		[CertManagerIssuerType].Name,
		$config,
		'Cert-Manager Issuer Type',
		[CertManagerIssuerType]::description,
		'Will you be using a ClusterIssuer instead of an Issuer resource?') {}

	[IQuestion]MakeQuestion([string] $prompt) {

		$choices = @(
			[tuple]::create('Yes', 'Yes, I plan to use a cert-manager ClusterIssuer resource'),
			[tuple]::create('No', 'No, I plan to use a cert-manager Issuer resource')
		)

		return new-object MultipleChoiceQuestion($prompt, $choices, -1)
	}

	[bool]HandleResponse([IQuestion] $question) {

		$choice = ([MultipleChoiceQuestion]$question).choice

		$this.config.certManagerIssuerType = $choice -eq 0 ? [IssuerType]::ClusterIssuer : [IssuerType]::Issuer
		return $true
	}

	[void]Reset(){
		$this.config.certManagerIssuerType = [IssuerType]::ClusterIssuer
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxCertManagerIngress
	}
}

class CertManagerIssuer : Step {

	static [string] hidden $description = @'
Specify the name of the cert-manager issuer you plan to use.

Note: Your cert-manager issuer must already exist.
'@

	static [string] hidden $issuerAnnotationKey = 'cert-manager.io/issuer'
	static [string] hidden $clusterIssuerAnnotationKey = 'cert-manager.io/cluster-issuer'

	CertManagerIssuer([ConfigInput] $config) : base(
		[CertManagerIssuer].Name, 
		$config,
		'Cert-Manager Issuer',
		[CertManagerIssuer]::description,
		'Enter the name of your cert-manager issuer') {}

	[bool]HandleResponse([IQuestion] $question) {

		$annotationKey = [CertManagerIssuer]::issuerAnnotationKey
		if ($this.config.certManagerIssuerType -eq [IssuerType]::ClusterIssuer) {
			$annotationKey = [CertManagerIssuer]::clusterIssuerAnnotationKey
		}

		$this.config.ingressAnnotationsCodeDx[$annotationKey] = ([Question]$question).response
		return $true
	}

	[void]Reset(){
		$this.config.ingressAnnotationsCodeDx.Remove([CertManagerIssuer]::issuerAnnotationKey)
		$this.config.ingressAnnotationsCodeDx.Remove([CertManagerIssuer]::clusterIssuerAnnotationKey)
	}

	[bool]CanRun() {
		return $this.config.ingressType -eq [IngressType]::NginxCertManagerIngress
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

		$isNetworkElb = $this.config.ingressType -eq [IngressType]::NetworkElb

		$backendProtocol = 'http'
		if (-not $this.config.skipTLS) {
			$backendProtocol = $isNetworkElb ? 'ssl' : 'https'
		}
		$this.config.serviceAnnotationsCodeDx = @{
			'service.beta.kubernetes.io/aws-load-balancer-backend-protocol' = $backendProtocol
			'service.beta.kubernetes.io/aws-load-balancer-ssl-ports' = 'https'
			'service.beta.kubernetes.io/aws-load-balancer-ssl-cert' = $certArn
		}
		if ($isNetworkElb) {
			$this.config.serviceAnnotationsCodeDx['service.beta.kubernetes.io/aws-load-balancer-type'] = 'nlb'
		}
		if ($this.config.IsElbInternalIngress()) {
			$this.config.serviceAnnotationsCodeDx['service.beta.kubernetes.io/aws-load-balancer-internal'] = 'true'
		}

		return $true
	}

	[void]Reset(){
		$this.config.serviceAnnotationsCodeDx = @{}
	}

	[bool]CanRun() {
		return $this.config.IsElbIngress()
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
