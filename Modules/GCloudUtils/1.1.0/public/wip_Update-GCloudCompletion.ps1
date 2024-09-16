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
        Get-GCloudCommandTree -ParentCommands '--help' -HashtableCache @{} | ConvertTo-Json -Compress -Depth 20 | Add-Content $completionFilepath
    }
    else {
      Write-Host "Completion file for gcloud version $gcloudVersion already exists: $completionFilepath"
      Write-Host 'Delete this file or rerun the command with the -Force parameter.'
    }
    try {
        [GCloud]::CompletionTree = Get-Content $completionFilepath -Raw | ConvertFrom-Json -AsHashtable #Import-Clixml $completionFilepath
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
      Write-Host "Completing gcloud args: $parentCmd" -ForegroundColor Green
      $toArgs = ($parentCmd -split ' ') + '--help'
      $previousKey = $toArgs[-2]
      if ( ($previousKey -in '--help', '-h' -or ( $toArgs | group | where count -gt 1)) -and ($toArgs -eq '--help').count -ne 2 ) {
        break
      }
      
      $isLeafCommand = $true
      $uniqueFlagsStart = $false
      $uniqueFlagsKeyIncrement = 0
      $active = $false

      $gcloudText = gcloud @toArgs
      foreach ($line in $gcloudText) {
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
        # If the help menu ever fully outdents and doesn't match the requisite words, deactivate $active
        if ( $active -and $line -cmatch '^[A-Z][A-Z ]+' -and $line -notmatch 'flag|command|group|topic') {
          $active = $false
        }
        # Skip lines where active has not been set to true or there is no line to parse
        if ( !$active -or !$line ) {
          continue
        }

        # prefilter the line so that we only process lines that could potentially contain a command for us to add to autocomplete.
        if ( $active -and $line -match '^\s{4,9}[-a-z_0-9]+($|[;,=](?=\s*[-[\S]+(.* default=.*)?$))') {#[-a-z_;=",[\].]+$))') {
          # Parse the line if it hasn't been skipped yet
          $addCommandParams = @{
            HashtableCache = $HashtableCache
            Line = $line
            GCloudText = $gcloudText
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
    [string[]]$GCloudText,
    [string]$CurrentCommand,
    [string]$PreviousKey,
    [Parameter(Mandatory)]
    [switch]$isUniqueFlags,
    [Parameter(Mandatory)]
    [switch]$isGcloudAllFlag
  )
  # To-Do: Add a fork in the flag workup for unique flags.
  # work up the key, the line indentation to the flag found, and make sure we have a copy of the help menu text for recursive parsing, as some
  # keys have multi-line implications regarding their enums and such, that it was easier to just reparse the help menu than continue line-by-line.
  $key = $Line -replace '^\s+(\S+).*$', '$1' -replace '[=,].*$'
  $lineIndentation = $Line -replace '(\s+).*$' , '$1'
  $gcloudHelpText = if ( !$GCloudText ) {
    $cmdAsNativeArgs = $CurrentCommand -split '\s+' #| where {$_}
    (gcloud @cmdAsNativeArgs --help) -join "`n"
  } else {
    $GCloudText -join "`n"
  }
  $regexSafeLine = [Regex]::Escape( ($Line -replace '^\s+') )

  # Check if key is a flag, i.e., preceded by --
  if ( $key -cmatch '^\s*--?[-a-z_0-9]+(?=$|=.*)' -and $key -ne $PreviousKey) {
    
    $indicatesEnumsWillBeProvided = @(
      'etermines\s+the\s+spec\s+of\s+endpoints\s+attached\s+to\s+this\s+group'
      'ust[\s]+be[\s]+one[\s]+of'
      'is[\s]+one[\s]+of[\s]+the[\s]+following'
      'ust[\s]+be[\s]+\(only[\s]+one[\s]+value[\s]+is[\s]+supported\)'
      'he\s+following\s+keys\s+are\s+allowed'
      'he\s+allowed\s+values\s+of\s+the\s+key\s+are\s+as\s+follows'
      'ossible\s+attributes\s+include'
      'ets\s+allowed_ports\s+value'
      'ets\s+boost_config\s+value'
    ) -join '|'

    if ( $enumBlock = (
      ($gcloudHelpText |
        Select-String "(?sm)^$lineIndentation$regexSafeLine$.*?(?=\n\n($lineIndentation\S|^[A-Z]))"
      ).Matches.Value |
        Select-String "(?m)^$lineIndentation\s{1,4}\S.*($indicatesEnumsWillBeProvided).*$"
    )) {
      # This regex selects for the above phrases and captures from the key, past that line, to the next key. If it's the last key in a set of flags,
      # then the next line will do a full outdent and begin with [A-Z], hence the or | at the every end.
      $values = if ( $enumBlock.Matches.Value -match '(?s): *\n? *\S.*$' ) {
        ($enumBlock -split ':\s*')[-1] -split '[,.]\s*' | foreach trim('[]') | where {$_ -match '^[-a-z0-9_]+$'}
      } else {
        $relevantLines = ($gcloudHelpText | 
        Select-String "(?sm)^$lineIndentation$regexSafeLine.*?^(\s+)[^\n]*($indicatesEnumsWillBeProvided)[.:][^\n]*\s*\n\n?.*?(?=\n$lineIndentation[-a-z]+|^[A-Z])"
      ).Matches.Groups[0].Value
        $relevantLines -split "`n" | where {$_ -match '^\s+[-a-z0-9_]+\s*$'} | foreach trim(' ')
      }
      
      #"(?sm)(?<=$regexSafeLine.*?)^(\s+)[^\n]+(must be one of|is one of the following):\s*\n\n.*?(?:\1([-a-z]+.*`$(?=\n\1))+)").Matches.Groups[0].Value
      # First if regex covers the case of "must be one of: <value>", where <value> may be wrapped in brackets, and also the case that the list of values
      # begins on the next line. The else covers the case of "must be one of: <double newline, then values separated by newlines and descriptions>"
      # Note that relevantLines has concatenated the output into a single string, so \s matches newlines.
      <#$values = if ( $relevantLines -match '(?s)must\s+be\s+one\s+of: *\n? *[-a-z'',[_"]+' ) {
        ($relevantLines -split ':\s*')[1] -split '[,.]\s*' | foreach trim('[]') | where {$_ -match '^[-a-z0-9_]+$'}
      } else {
        $relevantLines -split "`n" | where {$_ -match '^\s+[-a-z_]+\s*$'} | foreach trim(' ')
      }#>
      $HashtableCache.Add("$key=",$values)
    }
    # Handle flags that take an enum of values, with each enum having its own nested enum. See 'ai endpoints deploy-model'
    elseif ( $Line -match '(?sm)^(\s+)--.*=(\[[-a-z0-9[_,=]+|[-a-z0-9[_,=]+).*?[\]]$' ) {
      # First extract the enums to look for, as these are listed on the same line as the flag, e.g., FLAG=[ENUM1,...]. Not all Enums are listed here,
      # but we only need ENUM1 from the example.
      #[string[]]$partialFlagSubKeys = $Line -replace '^[^\[]+' -replace '[\[\]]' -split ',' | where { $_ -match '=' } | foreach { ($_ -split '=')[0] }
      #$testKey = $partialFlagSubKeys[0]
      # Now find the block of lines that start with the flag and end before the next flag. This is the block that we need to parse for the enums of the enums.
      #$relevantLines = ($gcloudHelpText | Select-String "(?sm)^$lineIndentation$key.+?\n\n.*?(?=^$lineIndentation[^\s])").Matches.Value -split "`n"
      
      # Take the first key from partialFlagSubKeys as a hint. Then find the line in the block of relevant lines that contains this hint. We sample this line
      # to get its indentation. It's assumed it will have the same indentation as all the enums, so we can parse the relevant lines for strings with the
      # same indentation and assume they are also enum values. This is how we find the remaining enums after ENUM1.
      
      #if ( $testKey -in 'KEY','PROPERTY' ) {
        $relevantLines = ($gcloudHelpText | Select-String "(?sm)(?<=^$lineIndentation$regexSafeLine.+?\n\n).*?(?=\s*^$lineIndentation[^\s])").Matches.Value
        $testLine = ( $relevantLines | Select-String '(?sm)^(\s+)\S[^\n]+?(?=\n^\1\s+[^\n]+$\n\1\s)').Matches.Value
      #} else {
      #  $relevantLines = ($gcloudHelpText | Select-String "(?sm)(?<=^$lineIndentation$key.+?\n\n).*?(?=\s*^$lineIndentation[^\s])").Matches.Value -split "`n"
      #  $testLine = $relevantLines | where {$_ -match "^\s+$testKey(?![-a-z])"} | Select-Object -First 1
      #}
      $getIndentation = $testLine -replace '^([\s]+).*$' , '$1' #' ' * ($testLine -replace '^([\s]+)\S.*' , '$1' | foreach Length)
      $allFlagSubKeys = if ( $testLine -and $getIndentation ) {
         $relevantLines -split "`n" | where {$_ -match "^$getIndentation\S+$"} | foreach trim(' ')
      } else { $null }
      # Only add the flag as a key with an empty hashtable if there are actually enum values found to populate that hashtable.
      if ( $allFlagSubKeys ) {
        $HashtableCache.Add("$key=", @{})
        # If there were no enums found, then treat it like a normal flag and pack it either into gcloudAllFlags or as just a regular flag in the else.
      } elseif ( $isGcloudAllFlag ) {
          write-debug "all flag is $key"
          $HashtableCache.gcloudAllFlags.Add($key)
      } else {
        $HashtableCache.Add($key, '')
      }
      # If subkeys (enums) were found, then also check for these enums had nested enums. Add these in if so.
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
    # Covers the case of enums defined for a specific command, which are preceded by either "must be one of", "is one of the following",
    # "must be (only one value is supported)". The \s in between every word is to account for cases where the preceding phrases wrap across
    # multiple lines.
    # see access-context-manager levels create, artifacts repositories create, artifacts docker image scan, ai-platform jobs submit training,
          # alloydb clusters create, alloydb instances create
          # hardest one: access-context-manager authorized-orgs create
    # Handle every other kind of flag
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
        if ( ! $HashtableCache.ContainsKey($flagName) ){$HashtableCache.Add($flagName, '')}
      }
    }
  }
  # Handle non flags.
  # 1 line: Any repeat keys are not included, and the key must begin with a-z and not be a flag (start with --)
  # 2 line: we can't control for the indentation as it can vary between 4,5,7,8, or 9 whitespaces. It may be possible for them
    # to be ::indent::<command>::whitespace::, so that we can't easily use regex to check if a line is a command or not. Therefore, we check that the
    # preceding line doesn't have the same indentation as our key, which would imply it is a block of descriptive text, since every command is followed
    # immediately by a further indented block of descriptive text.
  # 3 line: Check if the key is already in the hashtable to control for any of the enums of flags we searched for above and may have already added.
  elseif ( $key -ne $PreviousKey -and $key -match '^[a-z]' -and $key -notmatch '^--?' -and 
    ! ($gcloudHelpText | Select-String "(?sm)^$lineIndentation[^\n]+\n$lineIndentation$regexSafeLine").Matches -and
    ($key -notin $HashtableCache.Values.Keys -and $key -notin ($HashtableCache.Values | foreach {$_}) )
  ){
    $appendCommands = (($parentCmd -replace '--help') + ' ' + $key) -replace '^\s+' -replace '\s+$' -replace '\s{2,}', ' '
    
    Write-Verbose "command is $appendCommands"
    
    $value = Get-GCloudCommandTree -ParentCommands $appendCommands -HashtableCache @{}
    $HashtableCache.Add($key, $value)
  }
  return $HashtableCache
}


Update-GCloudCompletion -Force

#Make these into unit tests one day. They are commands that failed and required special cases in the code to account for.
#Get-GCloudCommandTree -ParentCommands 'alloydb clusters create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'alloydb instances create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'ai-platform jobs submit training' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'ai model-monitoring-jobs create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'artifacts docker images scan' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'ai endpoints deploy-model' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'artifacts repositories create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'access-context-manager levels create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'access-context-manager authorized-orgs create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'ai-platform jobs submit prediction' -HashtableCache @{}

#Get-GCloudCommandTree -ParentCommands 'ai-platform jobs submit training' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta compute instance-groups managed instance-configs create' -HashtableCache @{}

#Get-GCloudCommandTree -ParentCommands 'beta builds submit' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta compute forwarding-rules set-target' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta compute instance-groups managed instance-configs update' -HashtableCache @{}

#Get-GCloudCommandTree -ParentCommands 'beta compute backend-services create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta compute backend-services add-backend' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta compute backend-services update' -HashtableCache @{}

#Get-GCloudCommandTree -ParentCommands 'beta compute images create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta compute instances bulk create' -HashtableCache @{}

#Get-GCloudCommandTree -ParentCommands 'beta compute network-endpoint-groups create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta workstations configs create' -HashtableCache @{}
#Get-GCloudCommandTree -ParentCommands 'beta memcache instances create' -HashtableCache @{}


# Failing this command as it tries to add "container-image-uri" twice. It should be a unique flag. There are a number of other commands with the same
# issue. Too many to record—maybe 20-30 different command permutations (out of the 5k+, not bad!). I don't *think* these impact tab completion.
# Just an ugly error in the output of this command...probably.
#Get-GCloudCommandTree -ParentCommands 'ai custom-jobs create' -HashtableCache @{}

# hard af to get this one right, likely brittle to changes. I still failed on the scopes parameter, so it's not quite fully tab-complete compatible.
#Get-GCloudCommandTree -ParentCommands 'beta compute instance-templates create' -HashtableCache @{}

# Rekt on enum "short-name."" In general a lot of sub enums (enums to enums), and I miss all of these.
# Not the only command missing sub enums, but this one has some of the most missing sub enums. Expect tab completion here to be poor/incomplete.
#Get-GCloudCommandTree -ParentCommands 'beta compute instances ops-agents policies create' -HashtableCache @{}