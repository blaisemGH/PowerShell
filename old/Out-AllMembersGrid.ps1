### Source: https://stackoverflow.com/a/68036424/6076137
Function Out-AllMembersGrid {
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
    $collection     = [System.Collections.ArrayList]::new()
    $properties     = [System.Collections.ArrayList]::new()
    $propertiesList    = [System.Collections.ArrayList]::new()
  }

  process {
        $newInput        = [PSCustomObject]::New()
    $propertyNames   = @()

    ForEach ( $property in ($InputObject | Get-Member -MemberType Properties).Name ) { 
        $propName    = $property -Replace '([^_])_([^_])','$1__$2'
        $propValue    = $InputObject.$property
        $newInput | Add-Member -MemberType NoteProperty -Name $propName -Value $propValue -Force
        $propertyNames += $propName
        [void]$propertiesList.Add($propName)
    }
    [void]$collection.Add($newInput)
    #$properties.AddRange((($InputObject.PSObject.Properties).Name))
    $properties.AddRange($propertyNames)
  }

    end {
        if (!$noSortHeaders) {
            $properties = $properties | Select-Object -Unique
        } Else {
            $properties = $properties | Sort-Object -Unique
        }

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
        If ( $suppress ) {
            $exclude = '__errors','__row'
        }
        $collection | Select-Object -property * -ExcludeProperty $exclude | out-gridview -title $title
    }
}
