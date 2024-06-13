function Invoke-SplitOperator {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [object]$InputObject,

        [Parameter(Mandatory, Position = 1)]
        [string]$patternToSplitOn,
        
        [string]$howManyDelimitersToSplit
    )
    end {
        $Input -split $patternToSplitOn, $howManyDelimitersToSplit
    }
}