function Set-PSPromptConfig {
    param(
        [switch]$NoItemsOnLastLine,
        
        [string]$DefaultPromptBeckon,

        [Parameter(ParameterSetName='defaultmulti')]
        [switch]$SetDefaultMultilineConnector,

        [Parameter(ParameterSetName='multi')]
        [string[]]$SetMultilineConnector,

        [string[]]$SetSpaceBetweenItemSeparators,


        [PSPromptAlignment]$UseDefaultGroupMarkers,
        [object]$SetDefaultGroupMarkers
    )

    if ( $NoItemsOnLastLine ) {
        [PSPromptConfig]::NoItemsOnLastLine = $true
    }
    if ( $DefaultPromptBeckon ) {
        [PSPromptConfig]::DefaultPromptBeckon = $DefaultPromptBeckon
    }

    if ( $SetSpaceBetweenItemSeparators ) {
        $p = $SetSpaceBetweenItemSeparators
        if ( $p[0] -gt 0 ) {
            $terminalBackground = & {
                if ( 
                    $p[1] -in [Drawing.KnownColor].GetEnumNames() -or
                    $p[1] -match '^#[A-F0-9]{6}$' -or
                    $p[1] -match '^(([0-9]|1[0-9]{1,2}|2[0-5]{2});){2}([0-9]|1[0-9]{1,2}|2[0-5]{2})$'
                ) { $p[1] }
                else { '0;0;0' }
            }
            $fmtTerminalBackground = [ColorRGB]::TryParseString($terminalBackground).ToString()
        }
        [PSPromptConfig]::SetSpaceBetweenItemSeparators($p[0], $fmtTerminalBackground)
    }

    
}