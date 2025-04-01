Function Search-ObjectProperties {
    [OutputType([SearchObjectDTO])]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $InputObject,

        [Parameter(Position=0)]
        [string[]]$PropertiesToFind
    )
    begin {
        $searchObject = [SearchObjectProperties]::new($PropertiesToFind)
        $idx = -1
    }
    Process {
        Foreach ( $objectToSearch in $InputObject ) {
            if ( $searchObject.PropertiesToFind.count -gt 0) {
                $searchObject.Search_ObjectProperties($objectToSearch) | Where {$_}
            } else {
                [SearchObjectDTO]@{
                    Idx = ($idx += 1)
                    Value = $objectToSearch
                }
            }
        }
    }
}


<#
Function Search-ObjectProperties {
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $InputObject,

        [string[]]$PropertiesToFind
    )
    Process {
        Foreach ( $objectToSearch in $InputObject ) {
            If ( $objectToSearch -is [System.Collections.IEnumerable] -and $objectToSearch -isnot [string] -and $objectToSearch -isnot [hashtable] ) {
                Foreach ( $object in $objectToSearch ) {
                    Search-ObjectProperties $object -PropertiesToFind $PropertiesToFind
                }
            }
            
            ElseIf ( $objectToSearch -is [hashtable] ) {
                Foreach ( $key in [string[]]$objectToSearch.Keys ) {
                    [SearchObjectProperties]::TrackNodePath.Enqueue($prop)

                    if ( $key -in $PropertiesToFind ) {
                        [PSCustomObject]@{
                            Idx = ([SearchObjectProperties]::Index += 1)
                            NodePath = [SearchObjectProperties]::TrackNodePath -join '.'
                            Value = $objectToSearch.$key
                        }
                    }
                    Search-ObjectProperties $objectToSearch.$key -PropertiesToFind $PropertiesToFind
                    [void][SearchObjectProperties]::TrackNodePath.Dequeue()
                }
            }

            ElseIf ( $objectToSearch -is [PSCustomObject] ) {
                ForEach ( $prop in $objectToSearch.psobject.properties.name ) {
                    [SearchObjectProperties]::TrackNodePath.Enqueue($prop)

                    if ( $prop -in $PropertiesToFind ) {
                        [PSCustomObject]@{
                            Idx = ([SearchObjectProperties]::Index += 1)
                            NodePath = [SearchObjectProperties]::TrackNodePath -join '.'
                            Value = $objectToSearch.$prop
                        }
                    }
                    Search-ObjectProperties $objectToSearch.$prop -PropertiesToFind $PropertiesToFind
                    [void][SearchObjectProperties]::TrackNodePath.Dequeue()
                }
            }
        }
    }
}
#>