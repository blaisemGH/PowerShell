function Invoke-ReplaceOperator {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$patternToReplace,
        
        [Parameter(Position = 2)]
        [string]$replacement
    )
    end {
        $Input -replace $patternToReplace, $replacement
    }
}