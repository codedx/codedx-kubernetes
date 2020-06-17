<#PSScriptInfo
.VERSION 1.0.0
.GUID 77c7b99e-5383-41e1-8354-f2509f0b909d
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes functions for gathering input.
#>

function Read-HostYesNo([string] $title, [string] $message, [string] $yesHelp, [string] $noHelp) {

	if ($yesHelp -eq '') { $yesHelp = 'Yes'	}
	if ($noHelp -eq '') { $noHelp = 'No'	}

	Read-HostChoice $title $message @(
		[tuple]::Create('&Yes', $yesHelp),
		[tuple]::Create('&No',  $noHelp)
	) -1
}

function Read-HostChoice([string] $title, [string] $message, [tuple`2[string,string][]] $options, [int] $defaultOption) {

	if ($options.count -lt 2) {
		throw "Expected the options list for '$prompt' to contain at least two items."
	}

	$choices = @()
	$options | ForEach-Object {
		$choices += New-Object Management.Automation.Host.ChoiceDescription($_.Item1, $_.Item2)
	}
	
	(Get-Host).UI.PromptForChoice($title, $message, $choices, $defaultOption)
}