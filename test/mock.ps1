
function Get-QueuedInput {

	$val = $global:inputs.dequeue()
	if ($null -ne $val) {
		$val
		Write-Debug "'$val' dequeued"
	} else {
		Write-Debug 'null dequeued'
	}
}

function New-Mocks() {

	Mock Read-HostChoice {
		Write-Host $args
		Get-QueuedInput
	}

	Mock -ModuleName Guided-Setup Read-HostChoice {
		Write-Host $args
		Get-QueuedInput
	}

	Mock Read-Host {
		Write-Host $args
		Get-QueuedInput
	}

	Mock -ModuleName Guided-Setup Read-Host {
		Write-Host $args
		Get-QueuedInput
	}

	Mock Get-KubernetesEndpointsPort {
		return $global:k8sport
	}

	Mock Get-KubectlContexts {
		$global:kubeContexts
	}

	Mock Set-KubectlContext {
		Write-Host 'Selecting context...'
	}

	Mock Test-SetupPreqs {
		-not $global:prereqsSatisified
	}

	Mock Test-SetupKubernetesVersion {
		-not $global:prereqsSatisified
	}

	Mock Test-KeystorePassword {
		$global:keystorePasswordValid
	}

	Mock -ModuleName Guided-Setup Test-KeystorePassword {
		$global:keystorePasswordValid
	}

	Mock -ModuleName Guided-Setup Test-KeyToolCertificate {
		$global:caCertCertificateExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','extra1.pem','extra2.pem','storage-cert.pem' -contains $path }

	Mock Test-Path {
		$global:caCertFileExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','cacerts','extra1.pem','extra2.pem','idp-metadata.xml','sealed-secrets.pem','storage-cert.pem' -contains $path }

	Mock -ModuleName Guided-Setup Test-Path {
		$global:caCertFileExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','cacerts','extra1.pem','extra2.pem','idp-metadata.xml','sealed-secrets.pem','storage-cert.pem' -contains $path }

	Mock -ModuleName Guided-Setup Start-Sleep {
	}

	Mock Write-StepGraph {
	}

	Mock Test-CertificateSigningRequestV1Beta1 {
		$global:csrSupportsV1Beta1
	}

	Mock -ModuleName Guided-Setup Test-CertificateSigningRequestV1Beta1 {
		$global:csrSupportsV1Beta1
	}
}
