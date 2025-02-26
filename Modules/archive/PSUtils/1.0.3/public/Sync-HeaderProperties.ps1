using namespace System.Collections.Generic
<#
    .SYNOPSIS
        Synchronizes all the properties in the header of a collection of objects, so the output displays all properties in the collection.
        Source of code inspiration: https://stackoverflow.com/a/68036424/6076137
    .DESCRIPTION
        This function receives an object that consists of a collection of objects with inhomogenous object properties, and outputs a collection
        with a header that includes all properties present in the collection.
        
        The reason header modification is necessary is because PowerShell displays a property set based on the first item in a collection.
        All subsequent items in the collection with properties not present in the first item will not display these properties in the output.

        This function scans the entire collection for all properties and adds them to the first item, so the display is corrected.
        If a given object in the collection does not possess one of the properties added, the value defaults to $null (empty).
    .EXAMPLE
        $object | Sync-HeaderProperties
    .EXAMPLE
        $object | Sync-HeaderProperties -SortHeaders -ExcludeProperties '_TechnicalField1', 'Field2'
#>
Function Sync-HeaderProperties {
    param(
        [Parameter(ValueFromPipeline, Position=0)]
        [object[]]$InputObject,

        # Excludes certain properties from the output, if you are trying to curate a GridView for end users.
        [string[]]$ExcludeProperties,

        # Reorders all objects to the same order of headers in the output grid.
        [switch]$SortHeaders
    )

    begin {
        $outputList = [List[object]]::new()
        $propertiesSet = [HashSet[string]]::new([System.StringComparer]::InvariantCultureIgnoreCase)
    }

    process {
        ForEach ( $item in $InputObject ) {
            $propertiesSet.UnionWith([HashSet[String]]($item.psobject.Properties.Name))
            $outputList.Add($item)
        }
    }

    end {
        $finalHeaderCollection = & {
            If ($SortHeaders) {
                $propertiesSet | Where { $_ -notin $ExcludeProperties } | Sort-Object
            }
            Else {
                $propertiesSet | Where { $_ -notin $ExcludeProperties }
            }
        }

        $outputList[0] = Select-Object -InputObject $outputList[0] -Property $finalHeaderCollection
        return @($outputList)
    }
}
