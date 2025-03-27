using namespace YamlDotNet.Serialization
using namespace System.IO

class YamlData : IStructuredData {
    [StructuredDataUtils]$StructuredDataUtils
    [Deserializer]$Deserializer
    [Serializer]$Serializer
    [string]$FilePath

    <# Serializer options (https://github.com/aaubry/YamlDotNet/blob/master/YamlDotNet/Serialization/SerializerBuilder.cs)
        WithQuotingNecessaryStrings: Ints, Bool are wrapped in quotes. Necessary for k8s when it expects a string in a field type.
            Arg: $true. Also wraps bool values from the deprecated yaml 1.1 in quotes, e.g., yes/no etc. GKE still uses yaml 1.1 fields :)
        DisableAliases: Prints every field it finds instead of only once (I think this means it normally removes duplicates, but not sure).
                        At any rate, traversing for occurrences requires it to parse the entire object twice, once to check and once to write.
                        DisableAliases avoids a double parsing by writing everything in one pass.
    #>
    YamlData([bool]$asHashtable) {
        $this.StructuredDataUtils = [StructuredDataUtils]::new($asHashtable)
        #.WithNamingConvention(CamelCaseNamingConvention.Instance).Build()
        #.WithNamingConvention(UnderscoredNamingConvention.Instance).Build()
        $this.Deserializer = [DeserializerBuilder]::new().Build()
        $this.Serializer = [SerializerBuilder]::new().DisableAliases().Build()
    }
    YamlData([bool]$asHashtable, [string]$filePath) {
        $this.StructuredDataUtils = [StructuredDataUtils]::new($asHashtable)
        $this.Deserializer = [DeserializerBuilder]::new().Build()
        $this.Serializer = [SerializerBuilder]::new().DisableAliases().Build()
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
                $this.StructuredDataUtils.ConvertFromGenericDictionary(
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
        $genericDict = $this.StructuredDataUtils.ConvertToGenericDictionary($inputObject)
        $global:check = $genericDict
        return $this.Serializer.Serialize($genericDict)
    }
}
