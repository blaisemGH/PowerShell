Function Convert-AllHashtablesToPSCObjects {
    [OutputType([PSCustomObject])]
    Param(
        [Parameter(Mandatory,ValueFromPipeline)]
        $inputObject
    )

    Process {
        If ( $inputObject -is [System.Collections.IEnumerable] -and $inputObject -isnot [string] -and $inputObject -isnot [hashtable] ) {
            $collection = @(
                                Foreach ( $object in $inputObject ) {
                                    #write-host ("iterating $($object | out-string)")
                                    Convert-AllHashtablesToPSCObjects $object
                                }
                            )
            
            Write-Output $collection -NoEnumerate
        }
        
        ElseIf ( $inputObject -is [hashtable] ) {
            $cloneHash = $inputObject.Clone()
            Foreach ( $kvpair in $inputObject.GetEnumerator() ) {
                $cloneHash[$kvpair.key] = Convert-AllHashtablesToPSCObjects $kvpair.value
            }
            
            Write-Output ([PSCustomObject]$cloneHash)
        }
        
        Else {
            Write-Output $inputObject
        }
    }
}
