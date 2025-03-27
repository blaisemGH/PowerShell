Function Import-YamlFile {
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ValueFromPipelineByPropertyName)]
        [Alias('PSPath', 'LP')]
        [string[]]$Path
    )
    process {
        foreach ($file in $Path) {
            $validFilePath = Convert-Path -LiteralPath $file
            [YamlData]::new($file).Import()
        }
    }
}
