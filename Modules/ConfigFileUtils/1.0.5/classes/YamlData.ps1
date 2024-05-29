using namespace YamlDotNet.Serialization
using namespace System.IO

class YamlData : IStructuredData {
    [Deserializer]$Deserializer
    [Serializer]$Serializer
    [string]$FilePath

    YamlData() {
        #.WithNamingConvention(CamelCaseNamingConvention.Instance).Build()
        #.WithNamingConvention(UnderscoredNamingConvention.Instance).Build()
        $this.Deserializer = [DeserializerBuilder]::new().Build()
        $this.Serializer = [SerializerBuilder]::new().Build()
    }
    YamlData([string]$filePath) {
        $this.Deserializer = [DeserializerBuilder]::new().Build()
        $this.Serializer = [SerializerBuilder]::new().Build()
        $this.FilePath = $filePath
    }

    [PSCustomObject] Import() {
        return $this.ConvertFrom( (Get-Content $this.filePath -ErrorAction Stop) )
    }

    [PSCustomObject] Import([string]$filePath) {
        $fullFilePath = Convert-Path -LiteralPath $filePath -ErrorAction Stop
        return $this.ConvertFrom( (Get-Content $fullFilePath) )
    }
    [PSCustomObject] Import([FileInfo]$filePath) {
        return $this.ConvertFrom( (Get-Content $filePath) )
    }

    [PSCustomObject] ConvertFrom([string[]]$inputString) {
        $allYamlDocuments = $inputString -join "`n" -split '(?m)^---'

        return $(
            foreach ($yamlDocument in $allYamlDocuments) {
                $cleanYamlDocument = ($yamlDocument | Where {$_}) -join "`n"
                [StructuredDataUtils]::ConvertFromGenericDictionary(
                    $this.Deserializer.Deserialize( $cleanYamlDocument )
                )
            }
        )
    }

    [void] Export([object[]]$inputObject) {
        Set-Content -Path $this.FilePath -Value $this.ConvertTo($inputObject) -Force
    }
    [void] Export([object[]]$inputObject, [bool]$append) {
        if ( $append ) {
            Add-Content -Path $this.FilePath -Value '---' -Force
            Add-Content -Path $this.FilePath -Value $this.ConvertTo($inputObject) -Force
        } else {
            Set-Content -Path $this.FilePath -Value $this.ConvertTo($inputObject) -Force
        }
    }
    [void] Export([object[]]$inputObject, [string]$filePath) {
        Set-Content -Path $filePath -Value $this.ConvertTo($inputObject) -Force
    }
    [void] Export([object[]]$inputObject, [string]$filePath, [bool]$append) {
        if ( $append ) {
            Add-Content -Path $filePath -Value '---' -Force
            Add-Content -Path $filePath -Value $this.ConvertTo($inputObject) -Force
        } else {
            Set-Content -Path $filePath -Value $this.ConvertTo($inputObject) -Force
        }
    }

    [string[]] ConvertTo([object[]]$inputObject) {
        $genericDict = [StructuredDataUtils]::ConvertToGenericDictionary($inputObject)
        return $this.Serializer.Serialize($genericDict)
    }
}
