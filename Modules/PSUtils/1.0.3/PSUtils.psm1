#$importSource = @(
. "$PSScriptRoot/public/Convert-AllHashtablesToPSCObjects.ps1"
. "$PSScriptRoot/public/Convert-HashtableToOrderedDictionary.ps1"
. "$PSScriptRoot/public/Convert-ObjectToHashtable.ps1"
. "$PSScriptRoot/public/Join-ObjectLinq.ps1"
. "$PSScriptRoot/public/Test-ReadHost.ps1"
. "$PSScriptRoot/public/Test-ValidArgs.ps1"
. "$PSScriptRoot/public/Update-FileVersionIncrement.ps1"
. "$PSScriptRoot/public/Sync-HeaderProperties.ps1"
. "$PSScriptRoot/public/Move-FileToDatedFile.ps1"
. "$PSScriptRoot/public/Convert-MemoryUnits.ps1"
. "$PSScriptRoot/public/New-ErrorRecord.ps1"
#)
#$importSource.ForEach({
#    . (Join-Path $PSScriptRoot $_)
#})

Set-Alias -Name Count -Value Measure-CollectionCount -Scope Global -Option AllScope