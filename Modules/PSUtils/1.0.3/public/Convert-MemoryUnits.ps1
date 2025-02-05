function Convert-MemoryUnits {
    param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='MemoryInt')]
        [double]$MemoryInt,
        [Parameter(ParameterSetName='MemoryInt')]
        [string]$FromUnits = 'B',

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='MemoryString', Position=0)]
        [string]$MemoryString,
        
        [Parameter(Mandatory, Position=1)]
        [string]$ToUnits
    )
    process {
        $converter = switch ($PSCmdlet.ParameterSetName) {
            MemoryString {           
                [MemoryUnitConverter]::new($MemoryString, $ToUnits)
            }
            MemoryInt {
                [MemoryUnitConverter]::new($MemoryInt, $FromUnits, $ToUnits)
            }
        }
        $converter.ConvertMemory()
    }
}