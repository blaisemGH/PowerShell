using namespace System.Management.Automation

Function Test-ReadHost {  
<#
    .SYNOPSIS
        Loop a Read-Host query until the output fulfills a specified set of validation strings or is not empty.
#>
    [CmdletBinding(DefaultParameterSetName='NoValidation')]
    Param(
        # Message to display to user
        [Parameter(Mandatory)]
        [string]$Query,

        # List of strings to validate the user response against
        [Parameter(Mandatory,ParameterSetName='ValidateStrings')]
        [string[]]$ValidationStrings,

        # Regex pattern to validate the user response against
        [Parameter(Mandatory,ParameterSetName='ValidatePattern')]
        [object]$ValidationPattern,

        [Parameter(ParameterSetName='ValidateStrings')]
        [Parameter(ParameterSetName='ValidatePattern')]
        [switch]$CaseSensitive,

        # A default response if no validation is provided and the user presses enter without a response
        [string]$DefaultResponse,

        # An internal parameter to keep track of the number of times the user has failed validation.
        # If it ever reaches $maxRetries (defined below in the function body), an error is thrown.
        [Parameter(ParameterSetName='ValidateStrings')]
        [Parameter(ParameterSetName='ValidatePattern')]
        [int]$Retries = 0
    )
    $maxRetries = 5
    If ( $Retries -ge $maxRetries ) {
        If ( $DefaultResponse ) {
            return $DefaultResponse
        }
        $errMsg = "Failed to provide a valid response after $maxRetries tries! Parameters: $($PSBoundParameters | Out-String)"
        $PSCmdlet.ThrowTerminatingError( [ErrorRecord]::new($errMsg, 'RetriesExceeded', 'OperationStopped', $null) )
    }

    $response = Read-Host $Query

    switch ( $PSCmdlet.ParameterSetName ) {
        
        'ValidatePattern' {
            if ( $CaseSensitive -and $response -cmatch $ValidationPattern ) {
                return $response
            }
            if ( $response -match $ValidationPattern ) {
                return $response
            }
            Write-Warning "Response invalid! Case sensitive: $CaseSensitive. Must conform to pattern: $ValidationPattern"
            Write-Host ''
            return Test-ReadHost @PSBoundParameters -Retries ($Retries += 1)
        }

        'ValidateStrings' {
            if ( $CaseSensitive -and $response -cin $ValidationStrings ) {
                return $response
            }
            if ( $response -in $ValidationStrings ) {
                return $response
            }
            Write-Warning "Response invalid! Case sensitive: $CaseSensitive. Enter one of the following values:"
            Write-Host ''
            $ValidationStrings | % {Write-Host "`t $([char]::ConvertFromUtf32(0x2022)) $_" -Fore Yellow}
            Write-Host ''
            return Test-ReadHost @PSBoundParameters -Retries ($Retries += 1)
        }

        DEFAULT {
            If ( !$response ) {
                if ( $DefaultResponse ) {
                    return $DefaultResponse
                }
                return Test-ReadHost @PSBoundParameters
            }
            return $response
        }
    }
}
