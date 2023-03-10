Function Test-ValidArgs {
    Param(
        [Parameter(Mandatory,Position=0)]
        [Collections.Generic.HashSet[string]]$validationSet,
        [Parameter(Mandatory,Position=1)]
        [Collections.Generic.HashSet[string]]$inputSet
    )
    
    $compareSet = [System.Collections.Generic.HashSet[string]]::new([System.StringComparer]::InvariantCultureIgnoreCase)
    
    $compareSet.UnionWith($validationSet)
    
    $compareSet.IntersectWith($inputSet)
    
    If ( $compareSet.Count -eq 0 ) {
        Write-Host "Input Arguments = $inputSet"
        Write-Host "Valid Arguments = $validationSet"
        Throw "ERROR: The input arguments did not have any overlap with a valid argument! Please enter a single valid argument."
    }
    ElseIf ( $compareSet.Count -gt 1 ) {
        Write-Host "Input Arguments = $inputSet"
        Write-Host "Valid Arguments = $validationSet"
        Throw "ERROR: The input arguments matched more than 1 valid argument. Please enter a single valid argument only!"
    }
}
