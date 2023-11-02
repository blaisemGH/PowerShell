<#
	.SYNOPSIS
		This Function operates like a popd. It takes a numerical argument to move back a set number of directories.
#>
Function Back-Dir {
	
	[CmdletBinding()]
	Param (
	#[ValidateScript({
	#	If ( $_ -match "[\d]*" ) {true}
	#	Else { Throw 'please enter an integer as your argument. If no argument is entered, the default is 0'}
	#})]
		[int]$level = 0
	)

	#Push-Location (Get-Location -stack).Path[$level]
	ForEach ( $n in (0..$level) ) {
		Pop-Location
	}
}

Set-Alias -Name bd -Value Back-Dir