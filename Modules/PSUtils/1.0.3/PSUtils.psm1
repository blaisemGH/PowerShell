$importSource = @(
    './public/Convert-AllHashtablesToPSCObjects.ps1', 
    './public/Convert-HashtableToOrderedDictionary.ps1', 
    './public/Convert-ObjectToHashtable.ps1', 
    './public/Join-ObjectLinq.ps1', './public/Test-ReadHost.ps1', 
    './public/Test-ValidArgs.ps1', 
    './public/Update-FileVersionIncrement.ps1', 
    './public/Sync-HeaderProperties.ps1', 
    './public/Move-FileToDatedFile.ps1', 
    './public/Convert-MemoryUnits.ps1', 'public/New-ErrorRecord.ps1'
)
$importSource.ForEach({
    . (Join-Path $PSScriptRoot $_)
})

Set-Alias -Name Count -Value Measure-CollectionCount -Scope Global -Option AllScope