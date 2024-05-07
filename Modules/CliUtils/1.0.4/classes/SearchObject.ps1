using namespace System.Collections.Generic
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