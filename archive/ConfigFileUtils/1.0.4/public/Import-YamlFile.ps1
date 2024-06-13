Function Import-YamlFile {
    Param(
        [Parameter(Mandatory, ValueFromPipelineByPropertyName)]
        [Alias('PSPath')]
        [string]$Path,
        [switch]$asHashTable
    )
    process {
        [FileParser]::Yaml($Path, $asHashTable)
    }
}
