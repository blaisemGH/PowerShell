using namespace System.Collections.Generic
using namespace System.Collections

class SearchObjectDTO {
    [int]$Idx
    [object]$Value
}
class SearchObjectDTOFull : SearchObjectDTO {
    [string]$NodePath
}
class SearchObjectProperties {
    [Stack[string]]$TrackNodePath = @()
    [int]$Index = -1
    [HashSet[string]]$PropertiesToFind

    SearchObjectProperties(){}
    SearchObjectProperties([string[]]$PropertiesToFind){
        $this.PropertiesToFind = $PropertiesToFind
    }

    [SearchObjectDTO[]]Search_ObjectProperties([IList]$collection) {
        return $(
            foreach ( $item in $collection ) {
                if ( $this.Test_IsNestableObject($item) ) {
                    $this.Search_ObjectProperties($item)
                }
            }
        )
    }

    [object]Search_ObjectProperties([Hashtable]$hashtable) {
        return $(
            Foreach ( $key in [string[]]$hashtable.Keys ) {
                $this.TrackNodePath.Push($key)
                if ( $key -in $this.PropertiesToFind ) {
                    $reverseStackPath = $this.TrackNodePath.ToArray()
                    [Array]::Reverse($reverseStackPath)
                    [SearchObjectDTOFull]@{
                        Idx = ($this.Index += 1)
                        NodePath = $reverseStackPath -join '.'
                        Value = $hashtable.$key
                    }
                }

                if ( $this.Test_IsNestableObject($hashtable.$key) ) {
                    $this.Search_ObjectProperties($hashtable.$key)
                }
                
                [void]$this.TrackNodePath.Pop()
            }
        )
    }

    [object]Search_ObjectProperties([PSCustomObject]$psobject) {
        return $(
            foreach ( $prop in $psobject.psobject.properties.name ) {
                $this.TrackNodePath.Push($prop)
                if ( $prop -in $this.PropertiesToFind ) {
                    $reverseStackPath = $this.TrackNodePath.ToArray()
                    [Array]::Reverse($reverseStackPath)
                    [SearchObjectDTOFull]@{
                        Idx = ($this.Index += 1)
                        NodePath = $reverseStackPath -join '.'
                        Value = $psobject.$prop
                    }
                }
                if ( $this.Test_IsNestableObject($psobject.$prop) ) {
                    $this.Search_ObjectProperties($psobject.$prop)
                }

                [void]$this.TrackNodePath.Pop()
            }
        )
    }

    [bool]Test_IsNestableObject([object]$objectToTest) {
        # Some objects will return type literals, such as `Get-TypeData -Typename System.IO.FileInfo`, which seems to have unlimited nesting/causes some error.
        <#if (
            $objectToTest -isnot [ValueType] -and 
            $objectToTest -isnot [string] -and 
            $objectToTest -isnot [scriptblock] -and
            $objectToTest -isnot [type] -and
            $objectToTest -isnot [System.Management.Automation.Runspaces.TypeMemberData]
        ) {
            Refactored into positive matches instead of negative from isnot. Too many possible negative matches.#>
        if ($objectToTest -is [IList] -or $objectToTest -is [hashtable] -or $objectToTest -is [PSCustomObject]) {
            return $true
        }
        else { return $false }
    }

}

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