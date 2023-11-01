<#
	.SYNOPSIS
		A set of functions to convert from or to base64.
	.DESCRIPTION
		This function is a wrapper function for 2 other functions: ConvertFrom-Base64 and ConvertTo-Base64. The wrapper function is aliased to b64. By default, it runs ConvertTo-Base64, but if the switch Parameter Decode is specified, then it will run ConvertFrom-Base64.
		
		The functions are separated to keep in line with idiomatic PowerShell syntax for Convert[From|To]-[type], but the wrapper function is included for convenience and similarity to Unix—this module aliases the function to base64 and b64.
		
		The encoding defaults to UTF8 but can be changed via the Encoding parameter.
	.EXAMPLE
		# From UTF8 to Base64:
			ConvertTo-Base64 'abc'
			'abc' | ConvertTo-Base64
			'abc' | b64
	.EXAMPLE
		#From Base64 to UTF8:
			'YWJj' | ConvertFrom-Base64
			ConvertFrom-Base64 'YWJj'
			'YWJj' | b64 -decode
#>
Function Convert-Base64 {
	[CmdletBinding(DefaultParameterSetName = 'encode')]
	Param(
		[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[Alias('Line')]
		[string]$InputObject,
		[ArgumentCompleter({
			param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			(
				[Text.Encoding]::GetEncodings().Name + ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
			) |	Where-Object {
				$_ -like "$wordToComplete*"
			}
		})]
		[ValidateScript({
			If ($_ -in [Text.Encoding]::GetEncodings().Name -or 
				$_ -in ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
			) {
				$true
			}
			Else {
				Throw "$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]"
			}
		})]
		[string]$Encoding = 'UTF8',
		[Parameter(ParameterSetName='decode')]
		[switch]$Decode
	)
	Process {
		If ( $PScmdlet.ParameterSetName -eq 'decode' ) {
			Return ConvertFrom-Base64 -Encoding $Encoding -InputObject $InputObject
		}
		Else {
			Return ConvertTo-Base64 -Encoding $Encoding -InputObject $InputObject
		}
	}
}

Function ConvertFrom-Base64 {
	Param(
		[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[Alias('Line')]
		[string]$InputObject,
		[ArgumentCompleter({
			param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			(
				[Text.Encoding]::GetEncodings().Name + ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
			) |	Where-Object {
				$_ -like "$wordToComplete*"
			}
		})]
		[ValidateScript({
			If ($_ -in [Text.Encoding]::GetEncodings().Name -or 
				$_ -in ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
			) {
				$true
			}
			Else {
				Throw "$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]"
			}
		})]
		[string]$Encoding = 'UTF8'
	)
	
	Return [Text.Encoding]::$Encoding.GetString([Convert]::FromBase64String($InputObject))
}

Function ConvertTo-Base64 {
	Param(
		[Parameter(Mandatory,ValueFromPipeline,ValueFromPipelineByPropertyName)]
		[Alias('Line')]
		[string]$InputObject,
		[ArgumentCompleter({
			param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
			(
				[Text.Encoding]::GetEncodings().Name + ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
			) |	Where-Object {
				$_ -like "$wordToComplete*"
			}
		})]
		[ValidateScript({
			If ($_ -in [Text.Encoding]::GetEncodings().Name -or 
				$_ -in ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
			) {
				$true
			}
			Else {
				Throw "$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]"
			}
		})]
		[string]$Encoding = 'UTF8'
	)
	
	Return [Convert]::ToBase64String([Text.Encoding]::$Encoding.GetBytes($InputObject))
}