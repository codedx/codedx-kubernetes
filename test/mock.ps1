Import-Module 'pester'

function New-Mocks() {

	Mock Read-HostChoice {
		$val = $global:inputs.dequeue()
		if ($null -ne $val) {
			$val
		}
	}
	
	Mock Read-Host {
		$val = $global:inputs.dequeue()
		if ($null -ne $val) {
			$val
		}
	}

	Mock Get-KubernetesPort {
		return $global:k8sport
	}

	Mock Get-KubectlContexts {
		$global:kubeContexts
	}

	Mock Set-KubectlContext {
		Write-Host 'Selecting context...'
	}

	Mock Test-SetupPreqs {
		-not $global:missingPrereqs
	}

	Mock Test-KeystorePassword {
		$global:keystorePasswordValid
	}

	Mock Test-Certificate {
		$global:caCertCertificateExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','extra1.pem','extra2.pem' -contains $path }

	Mock Test-Path {
		$global:caCertFileExists
	} -ParameterFilter { 'ca.crt','db-ca.crt','cacerts','extra1.pem','extra2.pem' -contains $path }

	Mock Start-Sleep {
	}

	Mock Write-StepGraph {
	}
}
