
'utils.ps1','input.ps1','keytool.ps1' | ForEach-Object {
	$path = join-path $PSScriptRoot $_
	if (-not (Test-Path $path)) {
		Write-Error "Unable to find file script dependency at $path. Please download the entire codedx-kubernetes GitHub repository and rerun the downloaded copy of this script."
	}
	. $path
}

# Note: PowerShell doesn't support declaring an interface
class IQuestion { 
	[void]Prompt() {
		throw [NotImplementedException] 
	}
}

class Question : IQuestion {

	[string] $promptText

	[bool]   $hasResponse
	[bool]   $isResponseEmpty
	[string] $response

	[bool]   $isSecure
	[string] $validationExpr
	[string] $validationHelp
	[int]    $minimumLength
	[int]    $maximumLength

	[bool]   $allowEmptyResponse
	[string] $emptyResponseLabel = 'Accept Default'
	[string] $emptyResponseHelp = 'Use default value by providing no response'
	
	static [string] hidden $returnQuestionLabel = 'Return to Step'
	static [string] hidden $previousStepLabel = 'Back to Previous Step'

	Question([string] $promptText) {
		$this.promptText = $promptText
	}

	[void]Prompt() {
		
		[string] $result = ''
		while ($true) {

			$result = Read-HostText $this.promptText $this.minimumLength $this.maximumLength @() $this.isSecure $this.validationExpr $this.validationHelp -allowBlankEntry
			if ($result -ne '') {
				break
			}

			$options = @()
			if ($this.allowEmptyResponse) {
				$options += [tuple]::Create($this.emptyResponseLabel, $this.emptyResponseHelp)
			}
			$options += @(
				[tuple]::Create([question]::returnQuestionLabel, 'Provide a response to the question'),
				[tuple]::Create([question]::previousStepLabel,  'Go back to the previous step')
			)
			$choice = Read-HostChoice 'What do you want to do?' $options

			if (($options[$choice]).item1 -eq $this.emptyResponseLabel) {
				$this.isResponseEmpty = $true
				break
			}

			if (($options[$choice]).item1 -eq [question]::previousStepLabel) {
				$this.hasResponse = $false
				$this.response = ''
				return
			}
		}

		$this.hasResponse = $true
		$this.response = $result
	}

	[string] GetResponse([string] $whenEmpty) {
		if (!$this.hasResponse) {
			return $null
		}
		return $this.isResponseEmpty ? $whenEmpty : $this.response
	}
}

class ConfirmationQuestion : Question {

	ConfirmationQuestion([string] $promptText) : base($promptText) {
	}

	[void]Prompt() {

		$prompt = $this.promptText

		while ($true) {
		
			([Question]$this).Prompt()
			if (-not $this.hasResponse -or $this.isResponseEmpty) {
				break
			}
			$response = $this.response
			
			$this.promptText = 'Confirm'
			$this.response = ''

			([Question]$this).Prompt()
			if (-not $this.hasResponse -or $this.isResponseEmpty -or $response -eq $this.response) {
				break
			}
			
			Write-Host 'Responses do not match. Try again.'
			$this.promptText = $prompt
			$this.response = ''
		}
		$this.promptText = $prompt
	}
}

class IntegerQuestion : Question {

	[int] $minimum
	[int] $maximum

	[int]  $intResponse

	IntegerQuestion([string] $promptText, [int] $minimum, [int] $maximum, [bool] $allowEmptyResponse) : base($promptText) {

		if ($minimum -gt $maximum) {
			throw "Unexpected min/max values - $minimum is greater than $maximum."
		}

		$this.minimum = $minimum
		$this.maximum = $maximum
		$this.allowEmptyResponse = $allowEmptyResponse
		$this.validationExpr = "^\d+$"
		$this.validationHelp = "Enter a number between $minimum and $maximum."
	}

	[void]Prompt() {

		while ($true) {
			([Question]$this).Prompt()

			if (-not $this.hasResponse) {
				return
			}

			if ($this.isResponseEmpty) {
				break
			}

			[int] $val = 0
			if ([Int]::TryParse($this.response, [ref]$val)) {

				if ($val -lt $this.minimum -or $val -gt $this.maximum) {
					Write-Host $this.validationHelp
					continue
				}
				$this.intResponse = $val
				break
			}
		}
	}
}

class PathQuestion : Question {

	[microsoft.powershell.commands.testpathtype] $type

	PathQuestion([string] $promptText, [microsoft.powershell.commands.testpathtype] $type, [bool] $allowEmptyResponse) : base($promptText) {
		$this.type = $type
		$this.allowEmptyResponse = $allowEmptyResponse
	}

	[void]Prompt() {

		while ($true) {
			([Question]$this).Prompt()

			if (-not $this.hasResponse) {
				return
			}

			if ($this.isResponseEmpty) {
				break
			}

			if (Test-Path $this.response -PathType $this.type) {
				break
			}

			$pathType = 'file'
			if ($this.type -eq [microsoft.powershell.commands.testpathtype]::Container) {
				$pathType = 'directory'
			}
			Write-Host "Unable to read $pathType '$($this.response)' - the $pathType may not exist or you may not have permissions to read it - please enter another $pathType path"
		}
	}
}

class CertificateFileQuestion : PathQuestion {

	CertificateFileQuestion([string] $promptText, [bool] $allowEmptyResponse) : base($promptText, [microsoft.powershell.commands.testpathtype]::leaf, $allowEmptyResponse) {
	}

	[void]Prompt() {

		while ($true) {
			([PathQuestion]$this).Prompt()

			if (-not $this.hasResponse) {
				return
			}

			if ($this.isResponseEmpty) {
				break
			}

			if (Test-Certificate $this.response) {
				break
			}
			Write-Host "Unable to read certificate file '$($this.response)' - does the file contain a certificate?"
		}
	}
}

class EmailAddressQuestion : Question {

	EmailAddressQuestion([string] $promptText, [bool] $allowEmptyResponse) : base($promptText) {
		$this.allowEmptyResponse = $allowEmptyResponse
	}

	[void]Prompt() {

		while ($true) {
			([Question]$this).Prompt()

			if (-not $this.hasResponse) {
				return
			}

			if ($this.isResponseEmpty) {
				break
			}

			if (Test-EmailAddress $this.response) {
				break
			}
			Write-Host "'$($this.response)' is an invalid email address."
		}
	}
}

class MultipleChoiceQuestion : IQuestion {

	[string] $promptText
	[tuple`2[string,string][]] $options
	[int] $defaultOption

	[bool] $hasResponse
	[int]  $choice

	MultipleChoiceQuestion([string] $promptText, [tuple`2[string,string][]] $options, [int] $defaultOption) {
		$this.promptText = $promptText
		$this.options = $options
		$this.options += [tuple]::Create([question]::previousStepLabel, 'Go back to the previous step')
		$this.defaultOption = $defaultOption
	}

	[void]Prompt() {
		$this.choice = Read-HostChoice $this.promptText $this.options $this.defaultOption
		$this.hasResponse = $this.options[$this.choice].item1 -ne [question]::previousStepLabel
	}
}

class YesNoQuestion : MultipleChoiceQuestion {

	YesNoQuestion([string] $promptText, [string] $yesHelp, [string] $noHelp, [int] $defaultOption) : base($promptText, @(
		[tuple]::Create('Yes', $yesHelp),
		[tuple]::Create('No', $noHelp)
	), $defaultOption) {}
}
