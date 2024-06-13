Function Import-ConfigFile {
    [OutputType('PSCustomObject')]
    Param(
        [Alias('PSPath')]
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [string]$Path
    )
    Process {
        Return ([FileParser]::Import_ConfigFile($Path))
    }
}
