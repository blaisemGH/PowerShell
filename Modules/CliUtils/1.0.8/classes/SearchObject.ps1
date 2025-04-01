using namespace System.Collections.Generic
using namespace System.Collections
class SearchObject {
    [Stack[string]]$TrackNodePath = @()
    [int]$Index = -1
    [Regex]$matchIfSpaceSlashOrDotAndNoQuoteWrap = [Regex]::new( '^([^''"].*(?=[./ ].*).*[^''"])$', 'Compiled' )

    SearchObject() {}
}

class SearchObjectDTO {
    [int]$Idx
    [object]$Value
}
class SearchObjectDTOFull : SearchObjectDTO {
    [string]$NodePath
}

class SearchObjectValues : SearchObject {
    [string]$NodePath = ''
    
    SearchObjectValues(){}
    SearchObjectValues([string]$NodePath){
        $this.NodePath = $NodePath
    }
}

class SearchObjectProperties : SearchObject {
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
                $this.TrackNodePath.Push( ($key -replace $this.matchIfSpaceSlashOrDotAndNoQuoteWrap, '''$1''') )
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
                $this.TrackNodePath.Push( ($prop -replace $this.matchIfSpaceSlashOrDotAndNoQuoteWrap, '''$1''') )
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