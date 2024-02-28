<#
    .SYNOPSIS
        Loop a Read-Host query until the output fulfills a specified set of validation strings or is not empty.
#>

Function Test-ReadHost {
    Param(
        [Parameter(Mandatory)]
        [string]$Query,
        [string[]]$ValidationStrings,
        [string]$DefaultResponse,
        [int]$Retries = 0
    )
    $maxRetries = 5
    If ( $Retries -ge $maxRetries ) {
        If ( $DefaultResponse ) {
            return $DefaultResponse
        }
        Throw "Failed to provide a valid response after $maxRetries tries! Parameters: $($PSBoundParameters | Out-String)"
    }
    $response = Read-Host $Query

    If ( $DefaultResponse -and !$response ) {
        return $DefaultResponse
    }

    If ( !$ValidationStrings -and !$response) {    
        return Test-ReadHost @PSBoundParameters -Retries ($Retries += 1)
    }
    
    If  ( $response -in $ValidationStrings ) {
        return $response
    }
    Elseif ( $ValidationStrings ) {
        Write-Warning 'Please enter one of the following values:'
        Write-Host ''
        $ValidationStrings | % {Write-Host "`t $([char]::ConvertFromUtf32(0x2022)) $_" -Fore Yellow}
        Write-Host ''
        return Test-ReadHost @PSBoundParameters -Retries ($Retries += 1)
    }

    return $response
}
