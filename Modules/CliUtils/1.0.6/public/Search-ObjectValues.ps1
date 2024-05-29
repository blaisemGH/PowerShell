using namespace System.Collections.Generic

class SearchObjectValues : SearchObject {
    [string]$NodePath = ''
    
    SearchObjectValues(){}
    SearchObjectValues([string]$NodePath){
        $this.NodePath = $NodePath
    }
}

# Wrapper function for Find-ValueInObject. The purpose of the wrapper is to process the NodePath arg and facilitate a compiled Pattern.
# export
function Search-ObjectValues {
    [OutputType([PSCustomObject])]
    Param(
        [Alias('Value')]
        [Parameter(Mandatory, ValueFromPipeline)]
        $InputObject,

        [Parameter(ValueFromPipelineByPropertyName)]
        $NodePath,

        [Parameter(Position=0)]
        [string]$Pattern
    )
    begin {
        $compiledPattern = [Regex]::new($Pattern, 'Compiled')
    }
    process {
        Foreach ($object in $InputObject) {
            $objectToSearch, $sov = & {
                if ( $NodePath ) {
                    Select-NestedObject -InputObject $object.Value -PropertyNodes $NodePath -NodeSeparator '.'
                    [SearchObjectValues]::new($NodePath)
                } else {
                    $object
                    [SearchObjectValues]::new()
                }
            }

            Find-ValueInObject -InputObject $objectToSearch -Pattern $compiledPattern -UtilDTO $sov
        }
    }
}

Function Find-ValueInObject {
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
        $InputObject,

        [Parameter(Position=0)]
        [string]$Pattern,

        [SearchObjectValues]$UtilDTO
    )
    Process {
        Foreach ( $objectToSearch in $InputObject ) {
            If ( $objectToSearch -is [System.Collections.IEnumerable] -and $objectToSearch -isnot [string] -and $objectToSearch -isnot [hashtable] ) {
                Foreach ( $object in $objectToSearch ) {
                    Find-ValueInObject -InputObject $object -Pattern $Pattern -UtilDTO $UtilDTO
                }
            }
            
            ElseIf ( $objectToSearch -is [hashtable] ) {
                Foreach ( $key in [string[]]$objectToSearch.Keys ) {
                    $UtilDTO.TrackNodePath.Push(($prop -replace $UtilDTO.matchIfSpaceSlashOrDotAndNoQuoteWrap, '''$1'''))
                    Find-ValueInObject -InputObject $objectToSearch.$key -Pattern $Pattern -UtilDTO $UtilDTO
                    [void]$UtilDTO.TrackNodePath.Pop()
                }
            }

            ElseIf ( $objectToSearch -is [PSCustomObject] ) {
                ForEach ( $prop in $objectToSearch.psobject.properties.name ) {
                    $UtilDTO.TrackNodePath.Push(($prop -replace $UtilDTO.matchIfSpaceSlashOrDotAndNoQuoteWrap, '''$1'''))
                    if ( $objectToSearch.$prop ) {
                        Find-ValueInObject -InputObject $objectToSearch.$prop -Pattern $Pattern -UtilDTO $UtilDTO
                    }
                    [void]$UtilDTO.TrackNodePath.Pop()
                }
            }

            Else {
                $checkMatch = $cm = Select-String -InputObject $objectToSearch -Pattern $Pattern
                if ($checkMatch) {
                    $reverseStackPath = $UtilDTO.TrackNodePath.ToArray()
                    [Array]::Reverse($reverseStackPath)
                    [SearchObjectDTOFull]@{
                        Idx = ($UtilDTO.Index += 1)
                        NodePath = $UtilDTO.NodePath + '.' + ($reverseStackPath -join '.')
                        Value = $cm.ToEmphasizedString($cm.line) -replace ('>? ?' + ([regex]::Escape($cm.Path + ':' + $cm.LineNumber))  + ':')
                    }
                }
            }
        }
    }
}
