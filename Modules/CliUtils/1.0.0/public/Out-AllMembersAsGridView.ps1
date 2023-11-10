using namespace System.Collections.Generic
<#
	.DESCRIPTION
		This function takes in an object from the pipeline that consists of an array of objects with inhomogenous object properties, and outputs a homogenized representation as a graph. The reason this is necessary is because PowerShell only displays properties that are in common. For a table output, this means you would only see the columns that all objects in the array have in common. Any columns that aren't present in every object from the array would not be displayed. This function sets such columns to NULL, so that they may displayed graphically.
		Source: https://stackoverflow.com/a/68036424/6076137
	.EXAMPLE
		$object | Out-AllMembersAsGridView
		$obect | graph
#>
Function Out-AllMembersAsGridView {
    [Cmdletbinding(DefaultParameterSetName='OutputMode')]
    param(
        [Parameter(ValueFromPipeline, Position=0)]
        [object[]]$InputObject,
        [switch]$SortHeaders,
        [string]$Title = 'default',
        [string[]]$ExcludeProperties,
        [Parameter(ParameterSetName='OutputMode')]
        [ValidateSet('None', 'Single', 'Multiple')]
        [string]$OutputMode = 'None',
        [Parameter(ParameterSetName='PassThru')]
        [switch]$PassThru   
    )

    begin {
        $outputList 	= [List[object]]::new()
        $propertiesSet	= [HashSet[string]]::new()
        $gridViewParameters = @{ 'Title' = $Title }
        If ( $PSCmdlet.ParameterSetName -eq 'OutputMode' ) {
            $gridViewParameters.Add('OutputMode',$OutputMode)
        }
        ElseIf ( $PSCmdlet.ParameterSetName -eq 'PassThru' ) {
            $gridViewParameters.Add('PassThru',$PassThru)
        }
    }

    process {
        ForEach ( $item in $InputObject ) {
            $propertiesSet.UnionWith(([HashSet[String]]($item | Get-Member -MemberType Properties).Name))
            [void]$outputList.Add($item)
        }
    }

	end {
		$finalHeaderList = & {
            If ($SortHeaders) {
                $propertiesSet | Where { $_ -notin $ExcludeProperties } | Sort-Object -Unique
            }
            Else {
                $propertiesSet | Where { $_ -notin $ExcludeProperties }
            }
        }

        $(
            ForEach ( $object in $outputList ) {
                $object | Select-Object -Property $finalHeaderList
            }
        ) | Out-Gridview @gridViewParameters
	}
}