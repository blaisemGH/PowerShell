using namespace System.Collections.Generic
<#
    .DESCRIPTION
        This function receives an object that consists of a collection of objects with inhomogenous object properties, and outputs a homogenized
        representation as a PowerShell GridView (a graphical representation).
        
        The reason homogenization is necessary is because PowerShell fixes a property set based on the first item in a collection.
        All subsequent items in the collection with properties not present in the first item will not display these properties in the output.

        This function scans the entire collection for all properties and sets them to appear in the output.
        If a given object in the collection does not possess one of the properties added, the value defaults to $null (empty).
        
        Source of code inspiration: https://stackoverflow.com/a/68036424/6076137
    .EXAMPLE
        $object | Out-AllMembersAsGridView
    .EXAMPLE
        $object | Out-AllMembersAsGridView -Title 'MyObject' -OutputMode 'Multiple' -SortHeaders -ExcludeProperties '_TechnicalField1', 'Field2'
#>
Function Out-AllPropertiesInGridView {
    [Cmdletbinding(DefaultParameterSetName='OutputMode')]
    param(
        [Parameter(ValueFromPipeline, Position=0)]
        [object[]]$InputObject,

        # Sets the name of the GridView window.
        [string]$Title = 'PS GridView',

        # [None|Single|Multiple] Sets the OutputMode parameter for Out-GridView, passing a GridView selection to the output. Default: 'None'.
        [Parameter(ParameterSetName='OutputMode')]
        [Alias('om')]
        [ValidateSet('None', 'Single', 'Multiple')]
        [string]$OutputMode = 'None',

        # The GridView passes its output for further processing. Effectively the same as OutputMode = 'Multiple'.
        [Parameter(ParameterSetName='PassThru')]
        [Alias('pt')]
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
