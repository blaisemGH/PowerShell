Set-PSPromptMultilineConnector {
    param(
        [Parameter(Mandatory,ParameterSetName('Default'))]
        [switch]$Default,
        [Parameter(Mandatory,ParameterSetName('Custom'))]
        [string]$top,
        [Parameter(Mandatory,ParameterSetName('Custom'))]
        [string]$middle,
        [Parameter(Mandatory,ParameterSetName('Custom'))]
        [string]$bottom
    )

    if ( $PSCmdlet.ParameterSetName -eq 'Default' ) {
        [PSPromptConfig]::SetMultilineConnector()
    }
    else {
        [PSPromptConfig]::SetMultilineConnector($top, $middle, $bottom)
    }
}