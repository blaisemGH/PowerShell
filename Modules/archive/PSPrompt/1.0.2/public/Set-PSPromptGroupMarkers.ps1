function Set-PSPromptGroupMarkers {
    param(
        [Parameter(Mandatory,ParameterSetName='Default')]
        [Alias('Default')]
        [switch]$UseDefault,

        [Parameter(Mandatory,ParameterSetName='Global')]
        [Alias('Global')]
        [switch]$SetGlobalMarkers,
        
        [Parameter(Mandatory,ParameterSetName='Custom')]
        [string]$group,
        [Parameter(Mandatory,ParameterSetName='Custom')]
        [string]$openMarker,
        [Parameter(Mandatory,ParameterSetName='Custom')]
        [string]$closeMarker
    )
    dynamicParam {
        $dynParams = [RuntimeDefinedParameterDictionary]::new()
        if ( $SetGlobalMarkers ) {
            $attribute1 = [ParameterAttribute]::new()
            $attributeCollection1 = [Collection[System.Attribute]]@($attribute1)
            $param1 = [RuntimeDefinedParameter]::new('Alignment', [PSPromptAlignment], $attributeCollection1)
            $dynParams.Add('Alignment', $param1)

            $attribute2 = [ParameterAttribute]::new()
            $attributeCollection2 = [Collection[System.Attribute]]@($attribute2)
            $param2 = [RuntimeDefinedParameter]::new('GlobalOpenMarker', [string], $attributeCollection2)
            $dynParams.Add('GlobalOpenMarker', $param2)

            $attribute3 = [ParameterAttribute]::new()
            $attributeCollection3 = [Collection[System.Attribute]]@($attribute3)
            $param3 = [RuntimeDefinedParameter]::new('GlobalCloseMarker', [string], $attributeCollection3)
            $dynParams.Add('GlobalCloseMarker', $param3)
        }
        return $dynParams
    }

    if ( $PSCmdlet.ParameterSetName -eq 'Default' ) {
        [PSPromptConfig]::UseDefaultGroupMarkers($UseDefaultGroupMarkers)
    } elseif ( $SetDefaultGroupMarkers ) {
        $p = $SetDefaultGroupMarkers
        [PSPromptConfig]::SetDefaultGroupMarkers($p[0], $p[1])
    }

    [PSPromptConfig]::AddGroupMarkerMap($group, $openMarker, $closeMarker)
}