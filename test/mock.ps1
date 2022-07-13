
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
	
	Mock Read-Host {
		Write-Host $args
		Get-QueuedInput
	}

	Mock Get-KubernetesPort {
		return $global:k8sport
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

	Mock Test-Certificate {
		$global:caCertCertificateExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','extra1.pem','extra2.pem' -contains $path }

	Mock Test-Path {
		$global:caCertFileExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','cacerts','extra1.pem','extra2.pem','idp-metadata.xml','sealed-secrets.pem' -contains $path }

	Mock Start-Sleep {
	}

	Mock Write-StepGraph {
	}

	Mock Test-CertificateSigningRequestV1Beta1 {
		$global:csrSupportsV1Beta1
	}
}
