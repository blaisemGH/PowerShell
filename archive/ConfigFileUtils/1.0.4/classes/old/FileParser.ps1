using namespace System.Collections.Generic

# This class is used to parse yaml config files and import them into PowerShell as PS Objects
Class FileParser {

    static [PSCustomObject] Import_ConfigFile ( [string] $inputFilePath ) {
        try {
            $filePath = Convert-Path $inputFilePath
        }
        catch {
            Throw "FATAL! Cannot import file; file not found. Input path: $inputFilePath"
        }
        
        $fileType = Get-Item $filePath | Select-Object -ExpandProperty Extension
        
        Return $(
            switch -Regex ($fileType) {
                '.ya?ml' { [FileParser]::Yaml($filePath, $true) }
                '.json' { Get-Content $filePath | ConvertFrom-Json }
                '.psd1' { Import-PowerShellDataFile $filePath | Convert-AllHashtablesToPSCObjects }
                '(txt)|(prop.*)' { Get-Content $filepath | ConvertFrom-StringData | Convert-AllHashtablesToPSCObjects }
                DEFAULT {
                    Throw "ERROR: File extension does not match a supported type, '.json', 'yml', 'yaml', 'txt', 'properties', 'psd1'. The extension found was: $_."
                }
            }
        )
    }

    static [object] Yaml ( [string]$yamlFilePath, [bool]$asHashTable ) {
        $cleanPath = Convert-Path $yamlFilePath -ErrorAction Stop
        Return (
            Invoke-Expression (
                [YamlConverter]::new(
                    (Get-Content $cleanPath), $asHashTable
                ).Convert_YamlToPS() -join [Environment]::NewLine
            )
        )
    }
    
}
