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
function Update-GCloudCompletion {
    param (
      [switch]$Force
    )
    $gcloudVersion = Get-GCloudVersion
    $versionedCompletionFile = "gcloud-completion-v$($gcloudVersion.ToString()).json"
    $completionFilepath = Join-Path ([GCloud]::LocalCache) $versionedCompletionFile
    if ( ! (Test-Path $completionFilepath ) -or $Force ) {
        Get-GCloudCommandTree -ParentCommands '--help' -HashtableCache @{} | ConvertTo-Json $completionFilepath -Compress -Depth 20 | Add-Content $completionFilepath
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
            Write-Debug "Adding gcloudAllFlags"
            $HashtableCache.Add('gcloudAllFlags', [List[string]]::new() )
          }
          $isGcloudAllFlag = $true
        }
        if ( $line -cmatch '^[A-Z](?!LOBAL|THER)' ) {
          $isGcloudAllFlag = $false
        }
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
        #if ( $line -cmatch '^[A-Z](?!CLOUD.*WIDE.*FLAG)' ) {
        #  $isGcloudAllowedFlagList = $false
        #}
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
        if ( !$active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -match 'flag|command|group|topic' ) {
          Write-Verbose "activated on line: $line"
          $active = $true
          continue
        }
        if ( $active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -notmatch 'flag|command|group|topic') {
          $active = $false
        }
        # Skip lines where active has not been set to true or there is no line to parse
        if ( !$active -or !$line ) {
          continue
        }

        if ( $active -and $line -match '^\s{4,9}[-a-z]+($|[;,=](?=\s*[-[]+\S+$))') {#[-a-z_;=",[\].]+$))') {
          # Parse the line if it hasn't been skipped yet
          $addCommandParams = @{
            HashtableCache = $HashtableCache
            Line = $line
            CurrentCommand = $ParentCmd
            PreviousKey = $PreviousKey
            IsUniqueFlags = $isUniqueFlags
            isGcloudAllFlag = $isGcloudAllFlag
          }
          $HashtableCache = Add-GCloudCommandToCache @addCommandParams
          if ( $uniqueFlagsStart -and $line -match ' {7}-' ) {
            Write-Debug "Unique line $line"
          }
        }
        #if ( $line -match '^\s{5}[a-z]|^\s{5,}--?[a-z](?!.*[^,;] |.*\.$)' -and $line -match '^\s*[-A-Za-z0-9]+=?' ) {
          
          
        #}
      }
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
    [string]$CurrentCommand,
    [string]$PreviousKey,
    [Parameter(Mandatory)]
    [switch]$isUniqueFlags,
    [Parameter(Mandatory)]
    [switch]$isGcloudAllFlag
  )
  # gcloud artifacts docker images scan --help
    # I need to highlight the must be one of syntax and extract the key from this, which I then apply to that key. The problem is: 
    # gcloud  ai-platform jobs submit training --help
      # This has a command that switches the _ and -. So I need to replace the _ with a -, as all keys will use a - and not an _ 
  $key = $Line -replace '^\s+(\S+).*$', '$1' -replace '=.*$'
  if ( $line -match 'METRIC-NAME') {
    write-host 'breakpoint'
  }
  #if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=[A-Z]+($|;))' -and $key -ne $previousKey) {
  if ( $key -cmatch '^\s*--?[-a-z]+(?=$|=.*)' -and $key -ne $PreviousKey) {
    $cmdAsNativeArgs = $CurrentCommand -split '\s+' #| where {$_}
    $gcloudHelpText = (gcloud @cmdAsNativeArgs --help) -join "`n"
    $regexSafeLine = [Regex]::Escape($Line)
    # Handle flags that take multiple values, each of which has its own set of valid values.
    if ( $Line -match '^\s+--.*=\[[-a-z]+=.*[\]]' ) {
      [string[]]$partialFlagSubKeys = $Line -replace '^[^\[]+' -replace '[\[\]]' -split ',' | where { $_ -match '=' } | foreach { ($_ -split '=')[0] }
      $relevantLines = ($gcloudHelpText | Select-String "(?sm)^(\s+)$key.+?\n\n.*?(?=^\1[^\s])").Matches.Value -split "`n"
      $testKey = $partialFlagSubKeys[0]
      $testLine = $relevantLines | where {$_ -match "^\s+$testKey"}
      $getIndentation = ' ' * ($testLine -replace '^([\s]+)\S.*' , '$1' | foreach Length)
      $allFlagSubKeys = $relevantLines | where {$_ -match "^$getIndentation\S"} | foreach trim(' ')
      $HashtableCache.Add("$key=", @{})
      foreach ($subKey in $allFlagSubKeys) {
        $findSubkey = $gcloudHelpText |  Select-String "(?sm)(?<=^[\s]{9}$subKey.*?)^\s{10,}.*?(?=(\n\s)*^\s{5,9}[^\s])"
        $validValues = if ($findSubkey.Matches.Value -notmatch '.*hoices are ') {
          @()
        } else {
          $findSubkey.Matches.Value -split '.*hoices are ' -split ',\s*' | where {$_} | foreach trim("'.")
        }
        $HashtableCache."$key=".Add($subKey, $validValues)
      }
    }
    elseif ( ( ($gcloudHelpText | Select-String "(?s)$regexSafeLine.*?(?=\n\n)").Matches.Value | Select-String 'must be one of|is one of the following') ) {
      $relevantLines = ($gcloudHelpText | Select-String '(?sm)^(\s+)[^\n]+(must be one of|is one of the following):\s*\n\n.*?(?:\1([-a-z]+.*$(?=\n\1))+)').Matches.Groups[0].Value
      $values = if ( $relevantLines -match 'must be one of: \[' ) {
        ($relevantLines -split ': ')[1] -split ',\s*' | foreach trim('[]')
      } else {
        $relevantLines -split "`n" | where {$_ -match '^\s+[-a-z_]+\s*$'} | foreach trim(' ')
      }
      $HashtableCache.Add("$key=",$values)
    }
    else {
      # Some lines list multiple keys, like `--quiet, -q`
      $multiKeys = $key -split ',\s+'
      foreach ($flag in $multiKeys) {
        # Extract the key name from a string that looks like `--format=FORMAT`
        $flagName = ($flag -split '=')[0].trim(',;')
        Write-Verbose "flag is $flagName"
        if ( $isGcloudAllFlag ) {
          write-debug "all flag is $flagName"
          $HashtableCache.gcloudAllFlags.Add($flagName)
          continue
        }
        $HashtableCache.Add($flagName, '')
      }
    }
  }
  elseif ( $key -ne $PreviousKey -and $key -match '^[a-z]' -and $key -notmatch '^--?' -and ($key -notin $HashtableCache.Values.Keys -and $key -notin $HashtableCache.Values) ){
    $appendCommands = (($parentCmd -replace '--help') + ' ' + $key) -replace '^\s+' -replace '\s+$' -replace '\s{2,}', ' '
    
    Write-Verbose "command is $appendCommands"
    
    $value = Get-GCloudCommandTree -ParentCommands $appendCommands -HashtableCache @{}
    $HashtableCache.Add($key, $value)
  }
  return $HashtableCache
}

Update-GCloudCompletion -Force