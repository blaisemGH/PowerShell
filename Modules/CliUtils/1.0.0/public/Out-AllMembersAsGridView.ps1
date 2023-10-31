<#
	.DESCRIPTION
		This function takes in an object from the pipeline that consists of an array of objects with inhomogenous object properties, and outputs a homogenized representation as a graph. The reason this is necessary is because PowerShell only displays properties that are in common. For a table output, this means you would only see the columns that all objects in the array have in common. Any columns that aren't present in every object from the array would not be displayed. This function sets such columns to NULL, so that they may displayed graphically.
		Source: https://stackoverflow.com/a/68036424/6076137
	.EXAMPLE
		$object | Out-AllMembersAsGridView
		$obect | graph
#>
Function Out-AllMembersAsGridView {
  [Cmdletbinding()]
  param(
    [Parameter(ValueFromPipeline)]
    $InputObject,
    [Parameter()]
    [Alias('All')]
    [switch]
    $ExpandAll,
    [Parameter()]
    [switch]
    $noSortHeaders,
	[switch]
	$headersAdd,
	$title,
	[switch]
	$suppress
  )

  begin {
    $collection 	= [System.Collections.ArrayList]::new()
    $properties 	= [System.Collections.ArrayList]::new()
	$propertiesList	= [System.Collections.ArrayList]::new()
  }

  process {
	$newInput		= [PSCustomObject]::New()
	$propertyNames	= @()

	ForEach ( $property in ($InputObject | Get-Member -MemberType Properties).Name ) { 
		$propName	= $property -Replace '([^_])_([^_])','$1__$2'
		$propValue	= $InputObject.$property
		$newInput | Add-Member -MemberType NoteProperty -Name $propName -Value $propValue -Force
		$propertyNames += $propName
		[void]$propertiesList.Add($propName)
	}
	#[void]$collection.Add($InputObject)
    [void]$collection.Add($newInput)
    #$properties.AddRange((($InputObject.PSObject.Properties).Name))
	$properties.AddRange($propertyNames)
	#$properties.AddRange((($newObject | Get-Member -MemberType Property,NoteProperty).Name))
  }

	end {
		if (!$noSortHeaders) {
			$properties = $properties | Select-Object -Unique
		} Else {
			$properties = $properties | Sort-Object -Unique
		}
		#if ($ExpandAll) {
		#  for ($i = 0; $i -lt $collection.Count; ++$i) {
		#    $collection[$i] = $collection[$i] | Select-Object -Property $properties
		#  }
		#} Else {
		#  $collection[0] = $collection[0] | Select-Object -Property $properties
		#}
		#If ( $headersAdd ) {

		if ( $headersAdd ) {
			$propertyNames = $propertiesList | Sort-Object -unique
			$headersObject = [PSCustomObject]@{}
			Foreach ( $propertyName in $propertyNames ) {
				$headersObject | Add-Member -MemberType NoteProperty -Name $propertyName -Value $propertyName
			}
			$collection.Insert(0,$headersObject)
		}
		If (!$title) {
			$pipedInput = (Get-Content (Get-PSReadLineOption).HistorySavePath -Last 1).split('|')
			Foreach ($i in 0..$pipedInput.Count){
				If ($pipedInput[$i] -match 'graph') {
					$title = $pipedInput[$i - 1].split('.')[-1]
				}
			}
		}
		#$exclude = ''
		If ( $suppress ) {
			$exclude = '__errors','__row'
		}
		$collection | Select-Object -property * -ExcludeProperty $exclude | out-gridview -title $title
	}
}