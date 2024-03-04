Function Convert-ObjectToHashtable {
    [OutputType([Hashtable])]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $inputObject
    )

    Process {
        If ( $inputObject -is [System.Collections.IEnumerable] -and $inputObject -isnot [string] ) {
            $collection = @(
                                Foreach ( $object in $inputObject ) {
                                    Convert-ObjectToHashtable $object
                                }
                            )
            
            Write-Output $collection -NoEnumerate
        }
        
        ElseIf ( $inputObject -is [psobject] ) {
            $hashtable = @{}
            Foreach ( $property in $inputObject.psobject.properties ) {
                $hashtable.Add( $property.name , (Convert-ObjectToHashtable $property.value) )
            }
            
            $hashtable
        }
        
        Else {
            $inputObject
        }
    }
}
