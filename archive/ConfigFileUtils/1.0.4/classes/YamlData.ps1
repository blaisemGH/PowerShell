using namespace YamlDotNet.Serialization

class YamlData : IStructuredData {
    static [DeserializerBuilder]$Deserializer = [DeserializerBuilder]::new().Build()
    static [SerializerBuilder]$Serializer = [SerializerBuilder]::new().Build()

    static [PSCustomObject] Import([string]$filePath) {
        $cleanFilePath = Convert-Path $filePath -ErrorAction Stop
        return $this.ConvertFrom( (Get-Content $cleanFilePath) )
    }

    static [PSCustomObject] ConvertFrom([string[]]$yamlString) {
        $allYamlDocuments = $yamlString -join "`n" -split '(?m)^---'

        return $(
            foreach ($yamlDocument in $allYamlDocuments) {
                $cleanYamlDocument = ($yamlDocument | Where {$_}) -join "`n"
               [StructuredDataUtils]::ConvertFromGenericDictionary(
                    $this.Builder.Deserialize( $cleanYamlDocument )
                )
            }
        )
    }

    static [void] Export([object]$inputObject, [string]$filePath) {
        $cleanFilePath = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($filePath)
        Set-Content -Path $cleanFilePath -Value $this.ConvertToYaml($inputObject)
    }

    static [string[]] ConvertTo([object]$inputObject) {
        $genericDict = [StructuredDataUtils]::ConvertToGenericDictionary($inputObject)
        return $this.Builder.Serialize($genericDict)
    }
}
