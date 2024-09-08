using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
<#
to do in Get-GCloudCommandTree:
    1. group the global flags into a hashset in the gcloud class and always offer them in completion
    2. separate between groups or commands.

to do in Register-GCloudCompletion
    1. if there is a gcloudCmdProperties key, and the previous arg belongs to one of the command keys, then suggest one of the properties.
    2. if one of the keys is a property, then suggest a /attribute
#>
class GcloudCompletion {
  [ConcurrentDictionary[String, Hashtable]]$Hashtable = [ConcurrentDictionary[String, Object]]::new()
  [RunspaceRunner]$runspaceRunner

  GcloudCompletion() {
    $numberCores = (Get-ComputerInfo).CsNumberOfLogicalProcessors
    $maxCores = [Math]::Min( ($numberCores - 1), ($numberCores * 0.8))
    $parallelism = [Math]::Round( $maxCores, 0 )
    
    $iss = [initialsessionstate]::CreateDefault2()
    $f1Name = 'Get-GCloudCommandTree'
    $f1Definition = Get-Content Function:/Get-GCloudCommandTree
    $importFunction1 = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($f1Name, $f1Definition)
    $f2Name = 'Add-GCloudCommandToCache'
    $f2Definition = Get-Content Function:/Add-GCloudCommandToCache
    $importFunction2 = [System.Management.Automation.Runspaces.SessionStateFunctionEntry]::new($f2Name, $f2Definition)
    $iss.Commands.Add($importFunction1)
    $iss.Commands.Add($importFunction2)
    
    $sb = { param($Command) Get-GCloudCommandTree -ParentCommands $Command -HashtableCache @{} }

    $this.runspaceRunner = [RunspaceRunner]::new($iss, $sb, $parallelism)
  }
}
function Update-GCloudCompletion {
    param (
      [switch]$Force
    )
    $gcloudVersion = Get-GCloudVersion
    $versionedCompletionFile = "gcloud-completion-v$($gcloudVersion.ToString()).clixml"
    $completionFilepath = Join-Path ([GCloud]::LocalCache) $versionedCompletionFile
    if ( ! (Test-Path $completionFilepath ) -or $Force ) {
        $gcloudCompletion = [GcloudCompletion]::new()
        try {
          Get-GCloudCommandTree -ParentCommands '--help' -HashtableCache @{} -GcloudCompletion $gcloudCompletion | Export-Clixml $completionFilepath
        }
        finally {
          $gcloudCompletion.runspaceRunner.Close()
          $gcloudCompletion.runspaceRunner.Dispose()
        }
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
    [hashtable]$HashtableCache,
    [GcloudCompletion]$GcloudCompletion
  )
  begin {
    $active = $false
    $properties = $false
    $propKey = ''
  }
  process {
    foreach ( $parentCmd in $ParentCommands ) {
      Write-Host "Completing gcloud args: $parentCmd"
      $toArgs = ($parentCmd -split ' ') + '--help'
      $previousKey = $toArgs[-2]
      if ( ($previousKey -in '--help', '-h' -or ( $toArgs | group | where count -gt 1)) -and ($toArgs -eq '--help').count -ne 2 ) {
        break
      }
      
      $isLeafCommand = $true
      $uniqueFlagsStart = $false
      $uniqueFlagsKeyIncrement = 0

      foreach ($line in (gcloud @toArgs) ) {
        # Handle lists of arguments preceded by GLOBAL FLAGS or OTHER FLAGS.
        if ( $line -cmatch '^GLOBAL FLAGS' -or $line -cmatch '^OTHER FLAGS' ) {
          if ( ! $HashtableCache.ContainsKey('gcloudAllFlags' )) {
            $HashtableCache.Add('gcloudAllFlags', [List[string]]::new() )
          }
          $isGcloudAllFlag = $true
        }
        #if ( $line -cmatch '^[A-Z](?!LOBAL|THER)' ) {
        #  $isGcloudAllFlag = $false
        #}
        # Handle flags preceded by GCLOUD WIDE FLAGS. This a list of the flags allowed from the global or other flags list.
        if ( $line -cmatch '^GCLOUD.*WIDE.*FLAG' ) {
          Write-Debug 'adding gcloudAllowedAllFlags key'
          $HashtableCache.Add('gcloudAllowedAllFlags', [List[string]]::new())
          $isGcloudAllowedFlagList = $true
        }
        if ( $isGcloudAllowedFlagList ) {
          Write-Debug "Setting gcloud allowed flags on line $line"
          if ( $line -match '^\s*These flags are available to all commands' -or $line -match '^\s+--' ) {
            $HashtableCache.gcloudAllowedAllFlags.AddRange( [string[]]($line -split '[:,]\s*' -match '--' | foreach trim(". `t")) )
            $isGcloudAllowedFlagList = $false
            $active = $false
            continue
          }
          else {
            $isGcloudAllowedFlagList = $false
          }
        }
        if ( $line -cmatch '^[A-Z](?!CLOUD.*WIDE.*FLAG)' ) {
          $isGcloudAllowedFlagList = $false
        }

        # Handle positional arguments

          # gcloud  access-context-manager authorized-orgs create --help

        # Handle arguments preceded by COMMANDS
        if ( $line -cmatch '^COMMANDS' ) {
          $isLeafCommand = $false
        }
        # Handle arguments allowing only one of a subset of flags
        if ( $line -match '     At most one of these can be specified:' ) {
          $uniqueFlagsStart = $true
          $uniqueFlagsKeyIncrement += 1
          $HashtableCache.Add( ('uniqueFlags' + $uniqueFlagsKeyIncrement ), [List[string]]::new() )
        }
        if ( $uniqueFlagsStart -and $line -match ' {5}\S' ) {
          $uniqueFlagsStart = $false
        }

        # Handle properties, a special type of argument that is preceded by a line containing AVAILABLE PROPERT
        if ( $line -cmatch '^AVAILABLE PROPERT' ) {#-and $isLeafCommand ) {
            $properties = $true
            Write-Debug "set properties $properties"
            $HashtableCache.Add( 'commandProperties' , @{} )
            continue
        }
        if ( $properties -and $line -match '^\s{0,4}\S' ) {
            $properties = $false
            Write-Debug "set properties $properties"
            continue
        }

        # Begin parsing the line if it's for properties
        if ( $properties ) {
          if ( $line -match '^\s{5}[a-z]' ) {
            #write-host "propertyline is $line"
            $propKey = ($line -replace '^\s+(\S+).*$', '$1') + '/'
            $HashtableCache.commandProperties.Add( $propKey, [Collections.Generic.List[string]]::new() )
          }
          if (
            $line -match '^\s{9}[a-z]' -and
            $propKey -and
            $HashtableCache.ContainsKey('commandProperties') -and
            $HashtableCache.commandProperties.ContainsKey($propKey)
          ) {
            $propValue = $line -replace '^\s+(\S+).*$', '$1'
            #Write-Host "Adding value $propValue"
            $HashtableCache.commandProperties.$propKey.Add($propValue)
          }
          continue
        }

        # Set the loop to active, which means it will begin parsing all subsequent lines until active is set to false.
        if ( !$active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -match 'flag|command|group|topic|positional arg' ) {
          Write-Verbose "activated on line: $line"
          $active = $true
          continue
        }
        if ( $active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -notmatch 'flag|command|group|topic|positional arg') {
          $active = $false
        }
        # Skip lines where active has not been set to true or there is no line to parse
        if ( !$active -or !$line ) {
          continue
        }

        # Parse the line if it hasn't been skipped yet
        $addCommandParams = @{
          HashtableCache = $HashtableCache
          Line = $line
          PreviousKey = $PreviousKey
          IsUniqueFlags = $isUniqueFlags
          isGcloudAllFlag = $isGcloudAllFlag
        }
        
        $HashtableCache = if ( $GcloudCompletion ) {
          Add-GCloudCommandToCache @addCommandParams -GcloudCompletion $GcloudCompletion
        } else {
          Add-GCloudCommandToCache @addCommandParams
        }
         
        if ( $uniqueFlagsStart -and $line -match ' {7}-' ) {
          Write-Debug "Unique line $line"

        } 
      }
    }
    if ( $HashtableCache.ContainsKey('topLevelCommands') ) {
      $runspaceEntries = foreach ( $command in $HashtableCache.topLevelCommands ) {
        [RunspaceRunnerOrderedEntry]@{
          MarkId = $command
          Arguments = $command
        }
      }
      $commandCompletions = $GcloudCompletion.runspaceRunner.InvokeAllInOrder($runspaceEntries)
      $commandCompletions.GetEnumerator() | foreach {
        $HashtableCache.Add($_.Key, $_.Value)
      }
      $HashtableCache.Remove('topLevelCommands')
    }
    
    Write-Output $HashtableCache
  }
}

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
    [switch]$isGcloudAllFlag,
    [GcloudCompletion]$GcloudCompletion
  )

# Must be required to handle --quiet, -q
# Must fix 7 whitespace from 'gcloud  access-context-manager authorized-orgs create --help'
  $key = $Line -replace '^\s+(\S+).*$', '$1'
  #if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=[A-Z]+($|;))' -and $key -ne $previousKey) {
  if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=.*)' -and $key -ne $PreviousKey -and $Line -match '^\s{4,5}[^\s]' ) {
    # Some lines list multiple keys, like `--quiet, -q`
    $multiKeys = $key -split ',\s+'
    foreach ($flag in $multiKeys) {
      # Extract the key name from a string that looks like `--format=FORMAT`
      $flagName = ($flag -split '=')[0]
      Write-Verbose "flag is $flagName"
      if ( $isGcloudAllFlag ) {
        $HashtableCache.gcloudAllFlags.Add($flagName)
        continue
      }
      $HashtableCache.Add($flagName, '')
    }
  }
  elseif ( $key -ne $PreviousKey -and $key -cmatch '^[a-z]' -and $key -notmatch '^--?' -and $Line -match '^\s{4,5}[^\s]' ) {
    $appendCommands = (($parentCmd -replace '--help') + ' ' + $key) -replace '^\s+' -replace '\s+$' -replace '\s{2,}', ' '
    
    Write-Verbose "command is $appendCommands"
    
    if ( $GcloudCompletion ) {
      if ( !$HashtableCache.ContainsKey('topLevelCommands') ) {
        $HashtableCache.Add('topLevelCommands', [List[string]]::new())
      }
      $HashtableCache.topLevelCommands.Add($key)
    } else {
      $value = Get-GCloudCommandTree -ParentCommands $appendCommands -HashtableCache @{}
      $HashtableCache.Add($key, $value)
    }
  }
  return $HashtableCache
}