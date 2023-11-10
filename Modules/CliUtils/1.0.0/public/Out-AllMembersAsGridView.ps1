using namespace System.Collections.Generic
<#
    .DESCRIPTION
        This function takes in an object from the pipeline that consists of an array of objects with inhomogenous object properties, and outputs a homogenized representation as a graph. The reason this is necessary is because PowerShell only displays properties that are in common. For a table output, this means you would only see the columns that all objects in the array have in common. Any columns that aren't present in every object from the array would not be displayed. This function sets such columns to NULL, so that they may displayed graphically.
        Source of inspiration: https://stackoverflow.com/a/68036424/6076137

    .EXAMPLE
        $object | Out-AllMembersAsGridView
    
    .EXAMPLE
        $object | Out-AllMembersAsGridView -Title 'MyObject' -OutputMode 'Multiple' -SortHeaders -ExcludeProperties '_TechnicalField1', '_TechnicalField2'
#>
Function Out-AllMembersAsGridView {
    [Cmdletbinding(DefaultParameterSetName='OutputMode')]
    param(
        [Parameter(ValueFromPipeline, Position=0)]
        [object[]]$InputObject,

        # Sets the name of the GridView window.
        [string]$Title = 'PS GridView',

        # [None|Single|Multiple] Sets the OutputMode parameter for Out-GridView, allowing the user to output a single or multiple rows in the GridView selection. Default: 'None'.
        [Parameter(ParameterSetName='OutputMode')]
        [ValidateSet('None', 'Single', 'Multiple')]
        [string]$OutputMode = 'None',

        # The GridView passes its output for further processing. Effectively the same as OutputMode = 'Multiple'.
        [Parameter(ParameterSetName='PassThru')]
        [switch]$PassThru,

        # Excludes certain properties from the output, if you are trying to curate a GridView for end users.
        [string[]]$ExcludeProperties,

        # Reorders all objects to the same order of headers in the output grid.
        [switch]$SortHeaders
    )

    begin {
        $outputList = [List[object]]::new()
        $propertiesSet = [HashSet[string]]::new()

        $gridViewParameters = @{ 'Title' = $Title }
        If ( $PSCmdlet.ParameterSetName -eq 'OutputMode' ) {
            $gridViewParameters.Add('OutputMode',$OutputMode)
        }
        ElseIf ( $PSCmdlet.ParameterSetName -eq 'PassThru' ) {
            $gridViewParameters.Add('PassThru',$PassThru)
        }
        Else {
            $gridViewParameters.Add('Wait', $True)
        }
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
        $outputList | Out-Gridview @gridViewParameters
    }
}
