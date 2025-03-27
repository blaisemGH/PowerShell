$importSource = @(
    './public/ConvertFrom-StructuredData.ps1', 
    './public/ConvertTo-StructuredData.ps1', 
    './public/Export-StructuredDataFile.ps1', 
    './public/Import-StructuredDataFile.ps1', 
    './public/yaml/ConvertFrom-Yaml.ps1', 
    './public/yaml/ConvertTo-Yaml.ps1', 
    './public/yaml/Export-YamlFile.ps1', 
    './public/yaml/Import-YamlFile.ps1'
)

$importSource.ForEach({
    . (Join-Path $PSScriptRoot $_)
})

Set-Alias -Name cf -Value ConvertFrom-StructuredData -Scope Global -Option AllScope 
Set-Alias -Name ct -Value ConvertTo-StructuredData -Scope Global -Option AllScope

Set-Alias -Name cfy -Value ConvertFrom-Yaml -Scope Global -Option AllScope
Set-Alias -Name cty -Value ConvertTo-Yaml -Scope Global -Option AllScope

Set-Alias -Name cfj -Value ConvertFrom-Json -Scope Global -Option AllScope
Set-Alias -Name ctj -Value ConvertTo-Json -Scope Global -Option AllScope