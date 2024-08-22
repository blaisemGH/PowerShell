function Set-GCloudCompletion {
    param(
        [string]$ModuleHome = (Get-Module GCloudUtils | Select-Object -ExpandProperty ModuleBase)
    )
    $gcloudVersion = Get-GCloudVersion

    $tabCompletionDir = Join-Path $ModuleHome files
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

    [version]$useTabCompletionVersion = $latestVersionFile.Name -replace (
        '^.*-v([0-9]+(.[0-9])+)' + $latestVersionFile.Extension + '$'
    ), '$1'

    if ( $gcloudVersion -gt $useTabCompletionVersion ) {
        Write-Warning "Tab completion available for latest version, $useTabCompletionVersion. Your current version is $gcloudVersion."
        Write-Warning 'To update this, run the command Update-GCloudCompletion. This will take some time to update and may not be necessary if the gcloud sdk has no new commands.'
    }

    $tabCompletionFilepath = & {
        if ( $latestVersionFile.FullName -eq $defaultTabCompletionFile.FullName ) {
            $isAlreadyUnzipped = Get-ChildItem ([GCloud]::LocalCache) -Filter *.clixml | Where-Object { $_.BaseName -eq $defaultTabCompletionFile.BaseName }
            if ( ! $isAlreadyUnzipped ) {
                Expand-Archive $defaultTabCompletionFile -DestinationPath ([GCloud]::LocalCache)
            }
            Join-Path ([GCloud]::LocalCache) ($latestVersionFile.BaseName + '.clixml')
        }
        else {
            $latestVersionFile
        }
    }

    [GCloud]::CompletionTree = Import-Clixml $tabCompletionFilepath
    Register-GCloudCompletion
}

function Register-GCloudCompletion {
    $gcloudCompletion = {
        param($wordToComplete, $commandAst, $commandCharPosition)
        $argTokens = $commandAst.CommandElements.Extent.Text
        $ht = [GCloud]::CompletionTree
        $gcloudWideFlags = $ht.gcloudWideFlags | Sort-Object
        $ht.Remove('gcloudWideFlags')
        $completionStrings = foreach ( $token in ($argTokens | where { $_ -notmatch '^-' }) ){
            if ( $token -eq 'gcloud' ) { continue }
            if ( $ht.ContainsKey($token) ) { #-and !$flagIsCommandWithProperties...
                if ( $ht[$token].ContainsKey('commandProperties') ) {
                    $ht = $ht[$token].commandProperties
                }
                else {
                    $ht = $ht[$token]
                }
            }
            else {
                $ht.Keys | Where-Object { $_ -like "$wordToComplete*" }
            }
        }
        if ( !$wordToComplete ) {
            $ht.Keys
        }

        ($completionStrings | Sort-Object -Unique) + $gcloudWideFlags | Where-Object { $_ -notin $argTokens }
    }
    Register-ArgumentCompleter -CommandName gcloud -ScriptBlock $gcloudCompletion -Native
}