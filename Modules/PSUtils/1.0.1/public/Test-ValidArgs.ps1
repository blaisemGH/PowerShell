using namespace System.Collections.Generic
<#
    .SYNOPSIS
        When using the -contains operator, only a single value can be specified. This is inconvenient when you wish to check whether a collection contains multiple values.
        
        This function allows you to emulate -contains against multiple values, i.e., another collection. It returns the number of elements contained, which allows you to validate for different scenarios (see examples).
        
        The c
    .EXAMPLE
        # basic example to test whether a collection contains valid elements.
        if ( Test-ContainsCollection $myCollection $validElements ) {
            # do something
        }
    .EXAMPLE
        # This example tests if exactly 1 element matches. This can be useful for switch statements applied to an input argument, where you may only want to have a single valid case, for instance taking a specific action depending on a specific domain.

        if ( Test-ContainsCollection $myCollection $validElements -eq 1 ) {
            switch ( $myCollection) {...}
        }
#>
Function Test-ContainsCollection {
    [OutputType([int])]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [HashSet[string]]$InputSet,
        [Parameter(Mandatory)]
        [HashSet[string]]$ValidationSet,
        [switch]$CaseSensitive
    )
    begin {
        $compareOptions = & {
            If ( $CaseSensitive ) { [System.StringComparer]::InvariantCulture }
            Else { [System.StringComparer]::InvariantCultureIgnoreCase }
        }
    }
    process {
        $compareSet = [hashset[string]]::new($validationSet, $compareOptions)
        $compareSet.IntersectWith($inputSet)
        Write-Verbose "Input Arguments = $inputSet"
        Write-Verbose "Valid Arguments = $validationSet"

        Return $compareSet.Count
    }
}
