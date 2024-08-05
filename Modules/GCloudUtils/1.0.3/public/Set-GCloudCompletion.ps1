function Set-GCloudCompletion {
    $gcloudVersion = Get-GCloudVersion

    $tabCompletionDir = Join-Path $PSScriptRoot files
    $defaultTabCompletionFile = Get-ChildItem $tabCompletionDir -Filter *.zip | Sort-Object Name | Select-Object -Last 1

    $existingLocalCompletionFile = Get-ChildItem ([GCloud]::LocalCache) -Filter *-v*.clixml | Sort-Object | Select-Object -Last 1
    $latestVersionFile = & {
        if ( $existingLocalCompletionFiles.BaseName -eq $defaultTabCompletionFile.BaseName ) {
            $existingLocalCompletionFile
        }
        else {
            @($existingLocalCompletionFiles) + $defaultTabCompletionFile | Sort-Object {$_.BaseName} | Select-Object -Last 1
        }
    }

    if ( $latestVersionFileBaseName.FullName -eq $defaultTabCompletionFile.FullName ) {
        $isAlreadyUnzipped = Get-ChildItem ([GCloud]::LocalCache) -Filter *.clixml | Where-Object { $_.BaseName -eq $defaultTabCompletionFile.BaseName }
        if ( ! $isAlreadyUnzipped ) {
            Expand-Archive $defaultTabCompletionFile -DestinationPath ([GCloud]::LocalCache)
        }
    }

    [version]$useTabCompletionVersion = $latestVersionFile.Name -replace '^.*-v([0-9.]+)[.]clixml', '$1'

    if ( $gcloudVersion -gt $useTabCompletionVersion ) {
        Write-Warning "Tab completion available for latest version, $useTabCompletionVersion. Your current version is $gcloudVersion."
        Write-Warning 'To update this, run the command Update-GCloudCompletion. This will take some time to update and may not be necessary if the gcloud sdk has no new commands.'
    }

    [GCloud]::CompletionTree = Import-Clixml $latestVersionFile
    Register-GCloudCompletion
}

function Register-GCloudCompletion {
    $gcloudCompletion = {
        param($wordToComplete, $commandAst, $commandCharPosition)
        $argTokens = $commandAst.CommandElements.Extent.Text
        $ht = [GCloud]::CompletionTree
        foreach ( $token in $argTokens ) {
            if ( $token -eq 'gcloud' ) { continue }
            if ( $ht.ContainsKey($token) ) { #-and !$flagIsCommandWithProperties...
                $ht = $ht[$token]
            }
            else {
                $ht.Keys | Where-Object { $_ -like "$wordToComplete*" }
            }
            $flagIsCommandWithProperties = $true
            $flagIsProperty = $true
        }
        if ( !$wordToComplete ) { $ht.Keys }
    }
    Register-ArgumentCompleter -CommandName gcloud -ScriptBlock $gcloudCompletion -Native
}