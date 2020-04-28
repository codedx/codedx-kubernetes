<#PSScriptInfo
.VERSION 1.0.0
.GUID 64e7ba9e-d080-4e38-be2e-8c04eed6f183
.AUTHOR Code Dx
#>

<# 
.DESCRIPTION 
This script includes helper functions used by other scripts.
#>


function Convert-Base64([string] $file) {

	$path = join-path (get-location) $file
	$contents = [io.file]::ReadAllText($path)
	$contentBytes = [text.encoding]::ascii.getbytes($contents)
	[convert]::ToBase64String($contentBytes)
}

function Get-AppCommandPath([string] $commandName) {

	$command = Get-Command $commandName -Type Application -ErrorAction SilentlyContinue
	if ($null -eq $command) {
		return $null
	}
	$command.Path
}

function Test-IsBlacklisted([string] $text, [string[]] $blacklist) {

	$null -ne ($blacklist | Where-Object {
		$text -ceq $_ -or $text.Contains($_)
	})
}

function Read-HostText([string] $prompt, [int] $minimumLength, [int] $maximumLength, [string[]] $blacklist, [bool] $isSecure) {

	if ($prompt -eq '') {
		$prompt = ' '
	}

	$instruction = ''
	if ($minimumLength -ne 0) {
		if ($maximumLength -ne 0) {
			$instruction = "(length: $minimumLength-$maximumLength)"
		} else {
			$instruction = "(minimum length: $minimumLength)"
		}
	} else {
		if ($maximumLength -ne 0) {
			$instruction = "(maximum length: $maximumLength)"
		}
	}

	if ($minimumLength -eq 0) {
		$minimumLength = [int]::MinValue
	}
	if ($maximumLength -eq 0) {
		$maximumLength = [int]::MaxValue
	}

	while ($true) {
		$text = Read-Host -Prompt "$prompt$instruction" -AsSecureString:$isSecure
		if ($isSecure) {
			$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($text)
			$text = [Runtime.InteropServices.Marshal]::PtrToStringBSTR($BSTR)
		}
		if (($text -ne '') -and ($text.Length -ge $minimumLength) -and ($text.Length -le $maximumLength)) {
			
			if (Test-IsBlacklisted $text $blacklist) {
				Write-Host "The value cannot contain the following values; please try again.`n$blacklist"
				continue
			}
			return $text
		}
	}
}

function Read-HostSecureText([string] $prompt, [int] $minimumLength, [int] $maximumLength, [string[]] $blacklist) {
	Read-HostText $prompt $minimumLength $maximumLength $blacklist $true
}

function Invoke-GitClone([string] $url, [string] $branch) {

	git clone $url -b $branch
	if ($LASTEXITCODE -ne 0) {
		throw "Unable to run git clone with $url and branch $branch, git exited with code $LASTEXITCODE."
	}
}

function Test-IsCore {
	$PSVersionTable.PSEdition -eq 'Core'
}

function Test-IsElevated {

	if ($IsWindows) {
		return [bool](([Security.Principal.WindowsIdentity]::GetCurrent()).groups -match "S-1-5-32-544")
	}
	(id -u) -eq 0
}

function Get-IPv4AddressList([string] $hostname) {

	# not using Resolve-DnsName here because it's currently unavailable on ubuntu
	$entry = [net.dns]::gethostentry($hostname)
	$list = $entry.AddressList | Where-Object { -not $_.IsIPv6LinkLocal } | ForEach-Object { $_.IPAddressToString }
	[string]::Join(',', $list)
}
