using namespace System.Collections.Generic
<#
    .SYNOPSIS
        Outputs a collection of objects as a PowerShell GridView with all of their properties, even those missing in the first item of the collection.
        Source of code inspiration: https://stackoverflow.com/a/68036424/6076137
        See also the PSUtils module, function Sync-HeaderProperties, for a portable function.
    .DESCRIPTION
        This function receives an object that consists of a collection of objects with inhomogenous object properties, and outputs a homogenized
        representation as a PowerShell GridView (a graphical representation), with missing property values defaulting to empty ($null).
        
        The reason homogenization is necessary is because PowerShell fixes a property set based on the first item in a collection.
        The output suppresses any new properties from subsequent items, so they do not appear. This is particularly bad for Out-GridView.
        
        The "homogenization" is performed by adding all the unique properties that exist in the collection to the first item in the collection.
        This means only the first item in the collection is changed. It is purely a workaround for PowerShell's display.
        
        The logic for homogenization has been copied from the PSUtils module, function Sync-HeaderProperties.
        Effectively this function is equivalent to a wrapper that performs `Sync-HeaderProperties | Out-GridView`, but with unified input parameters.
        I avoided designing this function as a wrapper to prevent a cross-modular dependency just to support a niche gridview function.
    .EXAMPLE
        Out-AllPropertiesInGridView $object
    .EXAMPLE
        $object | Out-AllPropertiesInGridView -Title 'MyObject' -OutputMode 'Multiple' -SortHeaders -ExcludeProperties '_TechnicalField1', 'Field2'
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
        $propertiesSet = [HashSet[string]]::new([System.StringComparer]::InvariantCultureIgnoreCase)

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
