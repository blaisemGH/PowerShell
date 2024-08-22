using namespace System.Management.Automation
using namespace System.Collections.Generic
function Update-GCloudCompletion {
    param (
      [switch]$Force
    )
    $gcloudVersion = Get-GCloudVersion
    $versionedCompletionFile = "gcloud-completion-v$($gcloudVersion.ToString()).clixml"
    $completionFilepath = Join-Path ([GCloud]::LocalCache) $versionedCompletionFile
    if ( ! (Test-Path $completionFilepath ) -or $Force ) {
        Get-GCloudCommandTree -ParentCommands '--help' -HashtableCache @{} | Export-Clixml $completionFilepath
    }
    else {
      Write-Host "Completion file for gcloud version $gcloudVersion already exists: $completionFilepath"
      Write-Host 'Delete this file or rerun the command with the -Force parameter.'
    }
    try {
        [GCloud]::CompletionTree = Import-Clixml $completionFilepath
        Register-GCloudCompletion
    }
    catch {
        $_
    }
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
      $isLeafCommand = $true
      $uniqueFlagsStart = $false
      $uniqueFlagsKeyIncrement = 0
      foreach ($line in (gcloud @toArgs) ) {
        if ( !$active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -match 'flag|command|group|topic' ) {
          write-host "activated on line: $line"
          $active = $true
          continue
        }
        if ( $line -cmatch '^GLOBAL FLAGS' -or $line -cmatch '^OTHER FLAGS' ) {
          write-host $line
          if ( ! $HashtableCache.ContainsKey('gcloudWideFlags' )) {
            $HashtableCache.Add('gcloudWideFlags', [List[string]]::new() )
          }
          $isGcloudWideFlag = $true
        }
        if ( $line -cmatch '^[A-Z](?!LOBAL|THER)' ) {
          $isGcloudWideFlag = $false
        }
        if ( $line -cmatch '^COMMANDS' ) {
          $isLeafCommand = $false
        }
        if ( $line -match '     At most one of these can be specified:' ) {
          $uniqueFlagsStart = $true
          $uniqueFlagsKeyIncrement += 1
          $HashtableCache.Add( ('uniqueFlags' + $uniqueFlagsKeyIncrement ), [List[string]]::new() )
        }
        if ( $uniqueFlagsStart -and $line -match ' {5}\S' ) {
          $uniqueFlagsStart = $false
        }
        if ( $line -cmatch '^AVAILABLE PROPERT' -and $isLeafCommand ) {
            $active = $true
            $properties = $true
            write-host "set properties $properties"
            $HashtableCache.Add( 'commandProperties' , @{} )
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
            $propKey = ($line -replace '^\s+(\S+).*$', '$1') + '/'
            $HashtableCache.commandProperties.Add( $propKey, [Collections.Generic.List[string]]::new() )
          }
          if (
            $line -match '^\s{9}[a-z]' -and
            $propKey -and
            $HashtableCache.ContainsKey('properties') -and
            $HashtableCache.commandProperties.ContainsKey($propKey)
          ) {
            $propValue = $line -replace '^\s+(\S+).*$', '$1'
            Write-Host "Adding value $propValue"
            $HashtableCache.commandProperties.$propKey.Add($propValue)
          }
          continue
        }
        $addCommandParams = @{
          HashtableCache = $HashtableCache
          Line = $line
          PreviousKey = $PreviousKey
          IsUniqueFlags = $isUniqueFlags
          isGCloudWideFlag = $isGCloudWideFlag
        }
        $HashtableCache = Add-GCloudCommandToCache $addCommandParams
        if ( $uniqueFlagsStart -and $line -match ' {7}-' ) {
          Write-Host "Unique line $line"

        } 
        if ( $line -match '^\s{5}[a-z]|^\s{5,}--?[a-z](?!.*[^,;] |.*\.$)' -and $line -match '^\s*[-A-Za-z0-9]+=?' ) {
          
          
        }
      }
    }
    $HashtableCache
  }
}
<#
to do in Get-GCloudCommandTree:
    1. group the global flags into a hashset in the gcloud class and always offer them in completion
    2. separate between groups or commands.

to do in Register-GCloudCompletion
    1. if there is a gcloudCmdProperties key, and the previous arg belongs to one of the command keys, then suggest one of the properties.
    2. if one of the keys is a property, then suggest a /attribute
#> 

function Add-GCloudCommandToCache {
  param (
    [Parameter(Mandatory)]
    [Hashtable]$HashtableCache,
    [Parameter(Mandatory)]
    [string]$Line,
    [string]$PreviousKey,
    [Parameter(Mandatory)]
    [switch]$isUniqueFlags,
    [Parameter(Mandatory)]
    [switch]$isGCloudWideFlag
  )
  write-host $Line
  $key = $Line -replace '^\s+(\S+).*$', '$1'
  #if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=[A-Z]+($|;))' -and $key -ne $previousKey) {
  if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=.*)' -and $key -ne $PreviousKey) {
    # Some lines list multiple keys, like `--quiet, -q`
    $multiKeys = $key -split ',\s+'
    foreach ($flag in $multiKeys) {
      # Extract the key name from a string that looks like `--format=FORMAT`
      $flagName = ($flag -split '=')[0]
      write-host "flag is $flagName"
      if ( $isGcloudWideFlag ) {
        $HashtableCache.gcloudWideFlags.Add($flagName)
        continue
      }
      $HashtableCache.Add($flagName, '')
    }
  }
  elseif ( $key -ne $PreviousKey -and $key -cmatch '[a-z]' -and $key -notmatch '^--?') {
    $appendCommands = (($parentCmd -replace '--help') + ' ' + $key) -replace '^\s+' -replace '\s+$' -replace '\s{2,}', ' '
    
    Write-Host "command is $appendCommands"
    
    $value = Get-GCloudCommandTree -ParentCommands $appendCommands -HashtableCache @{}
    $HashtableCache.Add($key, $value)
  }
  return $HashtableCache
}