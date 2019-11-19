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

function Get-SecureStringText([string] $prompt, [int] $minimumLength) {

	if ($prompt -eq '') {
		$prompt = ' '
	}
	if ($minimumLength -gt 0) {
		$prompt = "$prompt (minimum length $minimumLength)"
	}

	while ($true) {
		$secureString = Read-Host -Prompt $prompt -AsSecureString
		$bstr = [Runtime.InteropServices.Marshal]::SecureStringToBSTR($secureString)
		$text = [Runtime.InteropServices.Marshal]::PtrToStringAuto($BSTR)
		if (($text -ne '') -and ($text.Length -ge $minimumLength)) {
			return $text
		}
	}
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