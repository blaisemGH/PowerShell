using namespace System.Management.Automation
function Update-GCloudCompletion {
    $gcloudVersion = Get-GCloudVersion
    $versionedCompletionFile = "gcloud-completion-v$($gcloudVersion.ToString()).clixml"
    $completionFilepath = Join-Path ([GCloud]::LocalCache) $versionedCompletionFile
    if ( ! (Test-Path $completionFilepath ) ) {
        Get-GCloudCommandTree -ParentCommands '--help' -HashtableCache @{} | Export-Clixml $completionFilepath
    }
    try {
        [GCloud]::CompletionTree = Import-Clixml $completionFilepath
        Register-GCloudCompletion
    }
    catch {
        $_
    }
}

function Get-GCloudVersion {
    [version]$gcloudVersion = (gcloud version | Select-String 'SDK') -split ' (?=\d)' | Select-Object -last 1
    if ( !$gcloudVersion ) {
        $err = "Could not obtain gcloud version via [version]((gcloud version | Select-String 'SDK') -split ' (?=\d)' | Select-Object -last 1)"
        $PSCmdlet.ThrowTerminatingError([ErrorRecord]::new($err, $null, 'ObjectNotFound', $null))
    }
    return $gcloudVersion
}

function Get-GCloudCommandTree {
    Param(
      [Parameter(ValueFromPipeline)]
      [string[]]$ParentCommands,

      [Parameter(Mandatory)]
      [hashtable]$HashtableCache
    )
    begin {
      $active = $false
      $properties = $false
      $propKey = ''
    }
    process {
      foreach ( $parentCmd in $ParentCommands ) {
        write-host "parent commands is/are $parentCmd"
        $toArgs = ($parentCmd -split ' ') + '--help'
        $previousKey = $toArgs[-2]
        if ( ($previousKey -in '--help', '-h' -or ( $toArgs | group | where count -gt 1)) -and ($toArgs -eq '--help').count -ne 2 ) {
          break
        }
        foreach ($line in (gcloud @toArgs) ) {
          if ( !$active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -match 'flag|command|group|topic' ) {
            write-host "activated on line: $line"
            $active = $true
            continue
          }
          if ( $line -cmatch '^AVAILABLE PROPERT' ) {
              $active = $true
              $properties = $true
              write-host "set properties $properties"
              $HashtableCache.Add( 'properties' , @{} )
              continue
          }
          if ( $properties -and $line -match '^\s{0,4}\S' ) {
              $properties = $false
              write-host "set properties $properties"
              continue
          }
          if ( !$active ) {
            continue
          }
          if ( $properties ) {
            if ( $line -match '^\s{5}[a-z]' ) {
              write-host "propertyline is $line"
              $propKey = $line -replace '^\s+(\S+).*$', '$1'
              $HashtableCache.properties.Add( $propKey, [Collections.Generic.List[string]]::new() )
            }
            if (
              $line -match '^\s{9}[a-z]' -and
              $propKey -and
              $HashtableCache.ContainsKey('properties') -and
              $HashtableCache.properties.ContainsKey($propKey)
            ) {
              $propValue = $line -replace '^\s+(\S+).*$', '$1'
              Write-Host "Adding value $propValue"
              $HashtableCache.properties.$propKey.Add($propValue)
            }
            continue
          }
          if ( $line -match '^\s{5}[a-z]|^\s{5,}--?[a-z](?!.*[^,;] |.*\.$)' -and $line -match '^\s*[-A-Za-z0-9=]+$' ) {
            write-host $line
            $key = $line -replace '^\s+(\S+).*$', '$1'
            if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=[A-Z]+($|;))' -and $key -ne $previousKey) {
              $multiKeys = $key -split ',\s+'
              foreach ($flag in $multiKeys) {
                $flagName = ($flag -split '=')[0]
                write-host "flag is $flagName"
                $HashtableCache.Add($flagName, '')
              }
            }
            elseif ( $key -ne $previousKey -and $key -cmatch '[a-z]' -and $key -notmatch '^--?') {
              $appendCommands = (($parentCmd -replace '--help') + ' ' + $key) -replace '^\s+' -replace '\s+$' -replace '\s{2,}', ' '
              write-host "command is $appendCommands"
              $value = Get-GCloudCommandTree -ParentCommands $appendCommands -HashtableCache @{}
              $HashtableCache.Add($key, $value)
            }
          }
        }
      }
      $HashtableCache
    }
  }
}
<#
to do in Get-GCloudCommandTree:
    1. group the global flags into a hashset in the gcloud class and always offer them in completion
    2. separate between groups or commands

to do in Register-GCloudCompletion
    1. if there is a gcloudCmdProperties key, and the previous arg belongs to one of the command keys, then suggest one of the properties.
    2. if one of the keys is a property, then suggest a /attribute
#> 
