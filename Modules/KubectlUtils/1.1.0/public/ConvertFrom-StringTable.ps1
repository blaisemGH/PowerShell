function ConvertFrom-StringTable {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [string[]]$InputObject
    )
    end {
        $Input -replace '\t', '    ' -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)
    }
}