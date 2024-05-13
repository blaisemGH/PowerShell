class YamlConfigFile : IConfigFile {
    [YamlDotNet.Serialization.DeserializerBuilder]$DeserializerBuilder

    YamlConfigFile() {
        $this.Builder = [YamlDotNet.Serialization.DeserializerBuilder]::new().Build()
    }

    [PSCustomObject] Import([string]$filePath) {
        $cleanFilePath = Convert-Path $filePath -ErrorAction Stop
        return $this.ConvertFrom( (Get-Content $cleanFilePath) )
    }

    [PSCustomObject] ConvertFrom([string[]]$yamlString) {
        $allYamlDocuments = $yamlString -join "`n" -split '(?m)^---'

        return $(
            foreach ($yamlDocument in $allYamlDocuments) {
                $cleanYamlDocument = ($yamlDocument | Where {$_}) -join "`n"
               [ConfigFileUtils]::ConvertFromGenericDictionary(
                    $this.DeserializerBuilder.Deserialize( $cleanYamlDocument )
                )
            }
        )
    }

}