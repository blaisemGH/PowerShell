using namespace System.Collections.Generic
using namespace System.Text
using namespace System.Drawing
using namespace System.Collections.Specialized

<#
There are 4 classes in this file:
 * PSPrompt: runtime calculation
 * PSPromptItem: DTO for end-user configuration, i.e., the properties available to the end user when submitting a configuration.
 * PSPromptConfig: state carrier of the entire prompt line and all its objects
 * PSPromptTemplate: static calculation (preprocessing). Interfaces PSPromptItem from end-user config to PSPrompt runtime object

To begin with a broad overview for an introduction, the intended flow is:
    1. User submits a config via wrapper function Add-PSPromptTemplateItem or direct invocation of PSPromptConfig.AddTemplate()
    2. The config is transformed into a PSPromptItem DTO in the constructor of PSPromptTemplate.
        Any config attribute not a property of PSPromptItem is skipped with a warning.
    3. The PSPromptItem DTO is refined into a PSPrompt object (PSPromptTemplate.GetTemplate())
    4. The PSPrompt object is cached in one of PSPromptConfig's sorted dictionaries based on its alignment. (PSPromptConfig)
    5. At runtime, PSPrompt.GetPrompt() loops through the sorted dictionaries and invokes/prints out the values for each item.
#>

<#
PSPrompt stores the final defining information for each element (synonym: item) on the prompt line.
Its method GetPrompt() runs every time the PS function prompt is called.
In short, this is the workhorse setting the prompt line at runtime.
#>
class PSPrompt {
    [ValidateRange(1)]
    [int]$GroupID = 0
    [ValidateRange(0)]
    [int]$LineToPrintOn = 1
    [string]$AnsiFormat
    [string]$BeginningText
    [object]$RawContent
    [scriptblock]$Content
    [string]$EndingText
    [string]$PlaceholderBeginningText
    [string]$PlaceholderEndingText
    [string]$ItemSeparator
    
    static [string] GetPrompt(){
        $ansiReset = "`e[0m"
        $setLastLine = [PSPromptConfig]::MultiLineConnector + [PSPromptConfig]::MultiLineConnectorOpenLastLine

        $leftItems = [PSPromptConfig]::PromptConfigsLeft
        $rightItems = [PSPromptConfig]::PromptConfigsRight
        $itemLines = @($leftItems.Values.LineToPrintOn) + @($rightItems.Values.LineToPrintOn) | Sort-Object -Unique
        $minItemLine = $itemLines[0]
        $maxItemLine = $itemLines[-1]

        $promptLines = foreach ( $line in $itemLines ) {
            $leftPrompt = (
                $leftItems.GetEnumerator() | Where-Object { $_.Value.LineToPrintOn -eq $line } | ForEach-Object {
                    $item = $_.Value
                    $body = try { & $item.Content ($ansiReset + $item.AnsiFormat) } catch {Write-Debug $_}
                    if ( $body ) {
                        $ansiReset + $item.BeginningText + $item.AnsiFormat + $body + $item.EndingText + $ansiReset
                    }
                }
            ) -join ''
            
            $rightPrompt = (
                $rightItems.GetEnumerator() | Where-Object { $_.Value.LineToPrintOn -eq $line } | ForEach-Object {
                    $item = $_.Value
                    $body = try { & $item.Content ($ansiReset + $item.AnsiFormat) } catch {Write-Debug $_}
                    $ansiReset + $item.BeginningText + $item.AnsiFormat + $body + $item.EndingText + $ansiReset
                }
            ) -join ''
            
            $lineConnector = if ( $line -eq $minItemLine ) {
                [PSPromptConfig]::MultiLineConnectorOpenFirstLine
            } elseif ( $line -eq $maxItemLine ) { 
                [PSPromptConfig]::MultiLineConnectorOpenLastLine
                $setLastLine = $null #Set it to null because the OpenLastLine connector will already be used here in $lineConnector.
            } else {
                [PSPromptConfig]::MultiLineConnectorOpenMiddleLine
            }

            $lengthMiddleWhiteSpace = [Console]::WindowWidth - ( ($leftPrompt -replace "`e[^m]+m").length + ($rightPrompt -replace "`e[^m]+m").length ) -   $lineConnector.Length
            
            $promptline = & {
                if ( ! $rightPrompt.Length ) {
                    $leftPrompt
                }
                elseif ( $lengthMiddleWhiteSpace -gt 0 ) {
                    $leftPrompt + ( ' ' * $lengthMiddleWhiteSpace ) + $rightPrompt
                }
                else {
                    $leftWhiteSpaceLength = [Console]::WindowWidth - ($rightPrompt -replace "`e[^m]+m").Length - [PSPromptConfig]::MultiLineConnectorOpenMiddleLine.Length
                    (
                        $leftPrompt + 
                        [Environment]::NewLine + 
                        [PSPromptConfig]::MultiLineConnectorOpenMiddleLine + 
                        ( ' ' * $leftWhiteSpaceLength ) + 
                        $rightPrompt
                    )
                }
            }

            $lineConnector + $promptLine
        }

        return (
            [Environment]::NewLine * [PSPromptConfig]::EmptyLinesToPrecedePromptline +
            ($promptLines -join [PSPromptConfig]::MultiLineConnector) +
            $setLastLine
        )
    }

}

<#
DTO for configuring an element in the prompt line. This represents the configuration interface available to the end user.
These config properties are refined into the final PSPrompt properties which are invoked by the PS prompt function at runtime.
PSPromptItem inherits from PSPrompt to allow one to bypass the refining logic and directly inject PSPrompt elements.
Direct injection is a backdoor for flexibility but not the intended standard use case.
#>
class PSPromptItem : PSPrompt {
    [PSPromptAlignment]$Alignment
    [object]$ForegroundColor
    [object]$BackgroundColor
    [AnsiEffectsFlags]$AnsiEffects
    [scriptblock]$ContentFunction
    [bool]$DoNotRecalculateContentValue
    [string]$Group
    [int]$ItemPosition
}

<#
This class caches all the state used by this module. In particular,
$PromptConfigsLeft and $PromptConfigsRight store each element's logic and is invoked by PSPrompt to generate the prompt item.
The remaining properties configure formatting information, e.g., how to handle multiple lines, how to separate groups, etc.
#>
class PSPromptConfig {
    static [SortedDictionary[int,PSPrompt]]$PromptConfigsLeft = @{}
    static [SortedDictionary[int,PSPrompt]]$PromptConfigsRight = @{}
    static [string]$MultiLineConnector
    static [string]$MultiLineConnectorOpenFirstLine
    static [string]$MultiLineConnectorOpenMiddleLine
    static [string]$MultiLineConnectorOpenLastLine
    static [int]$EmptyLinesToPrecedePromptline = 0
    static [int]$SpacesBetweenItemSeparators = 0
    static [string]$TerminalBackgroundColor = ($host.ui.RawUI.BackgroundColor)
    static [OrderedDictionary]$GroupMarkerMaps = [ordered]@{ 0 = @{
        open = ''
        close = ''
    }}
    # These are -1 so that they will not be used by default. They are activated by setting to 0 (see UseDefaultGroupMarkers())
    static [int]$DefaultGroupIDLeft = -1
    static [int]$DefaultGroupIDRight = -1
    static [OrderedDictionary]$MapGroupIDToNames = [ordered]@{0 = '0'}
    
    static [void] AddTemplate ([hashtable]$configToAdd) {
        $alignment = if ( $configToAdd.Alignment -eq 'Right' ) { 'Right' } else { 'Left' }

        # Select the left or right aligned configs, and force apply the MultiLineConnector if right aligned.
        if ( $alignment -eq 'Right' ) {
            # A right alignment requires multiline usage.
            if ( !([PSPromptConfig]::MultiLineConnector) ) {
                [PSPromptConfig]::SetMultilineConnector()
            }
            $alignedConfigDict = [PSPromptConfig]::PromptConfigsRight
        }
        else {
            $alignedConfigDict = [PSPromptConfig]::PromptConfigsLeft
        }
        
        # Prevent the same item from being added twice. Checks to see if the input function already exists.
        if ( $alignedConfigDict.Values.RawContent ) {
            $alignedConfigDict.Values | ForEach {
                if ( $_.RawContent.ToString() -eq $configToAdd.ContentFunction.ToString() ) {
                    break
                }
            }
        }
        
        [PSPromptConfig]::RemoveDefaultTemplate($alignedConfigDict)

        $PSPromptTemplate = [PSPromptTemplate]::new($configToAdd)
        
        $template = $PSPromptTemplate.GetTemplate($alignedConfigDict)

        # Resolve the final ItemPosition to be used.
        $itemPosition = $PSPromptTemplate.GetItemPosition($alignedConfigDict)
        $alignedConfigDict.Add($itemPosition, $template)
        
        # After a template has been added to the list of items, backtrack through the config dict and reapply any group markers.
        if ( [PSPromptConfig]::"DefaultGroupID$alignment" -ge 0 ) {
            $PSPromptTemplate.SetGroupMarkers($alignedConfigDict)
        } else {
            if ( $alignedConfigDict.Count -gt 1) {
                $firstItem = $alignedConfigDict.Keys | Select -First 1
                $alignedConfigDict[$firstItem].BeginningText = ''
            }
        }

    }
    
    # An alternative constructor to forcibly add a config without any preprocessing. A backdoor to explicitly inject a config.
    static [void] AddTemplate ([PSPrompt]$promptItem, [int]$id, [PSPromptAlignment]$alignment) {
        [PSPromptConfig]::RemoveDefaultTemplate()
        if ( $alignment -eq 'Left' ) {
            [PSPromptConfig]::PromptConfigsRight.Add($id, $promptItem)
        }
        [PSPromptConfig]::PromptConfigsLeft.Add($id,$promptItem)
    }

    static [void] RemoveDefaultTemplate() {
        ([hashtable][PSPromptConfig]::PromptConfigsLeft).Clone().GetEnumerator() |
            Where {[int]$_.Key -lt 1} | 
            ForEach {
                [PSPromptConfig]::PromptConfigsLeft.Remove($_.Key)
            }
            
        ([hashtable][PSPromptConfig]::PromptConfigsRight).Clone().GetEnumerator() |
            Where {[int]$_.Key -lt 1} | 
            ForEach {
                [PSPromptConfig]::PromptConfigsRight.Remove($_.Key)
            }
    }
    static [void] RemoveDefaultTemplate([SortedDictionary[int,PSPrompt]]$promptConfig) {
        ([hashtable]$promptConfig).Clone().GetEnumerator() |
            Where {[int]$_.Key -lt 1} | 
            ForEach {
                $promptConfig.Remove($_.Key)
            }
    }

    static [void] UseDefaultGroupMarkers ( [PSPromptAlignment]$alignment ) {
        if ( $alignment.ToString() -eq 'Right' ) {
            [PSPromptConfig]::DefaultGroupIDRight = 0
        }
        else {
            [PSPromptConfig]::DefaultGroupIDLeft = 0
        }
    }
    static [void] UseDefaultGroupMarkers ( [PSPromptAlignment]$alignment, [Hashtable]$defaultMarkerSet) {
        if ( $alignment.ToString() -eq 'Right' ) {
            [PSPromptConfig]::DefaultGroupIDRight = 0
        }
        else {
            [PSPromptConfig]::DefaultGroupIDLeft = 0
        }
        [PSPromptConfig]::GroupMarkerMaps[0] = $defaultMarkerSet
    }

    static [void] AddGroupMarkerMap ([int]$id, [string]$openMarker, [string]$closeMarker) {
        $groupMapping = @{
            open = $openMarker
            close = $closeMarker
        }
        [PSPromptConfig]::GroupMarkerMaps.add($id, $groupMapping)
    }
    static [void] AddGroupMarkerMap ([int]$id ) {
        $groupMapping = @{
            open = ''
            close = ''
        }
        [PSPromptConfig]::GroupMarkerMaps.add($id, $groupMapping)
    }
    
    static [void] SetMultilineConnector() {
        [PSPromptConfig]::MultiLineConnector = [Environment]::NewLine
        [PSPromptConfig]::MultiLineConnectorOpenFirstLine = [char]0x0250C
        [PSPromptConfig]::MultiLineConnectorOpenMiddleLine = [char]0x02502
        [PSPromptConfig]::MultiLineConnectorOpenLastLine = [char]0x02514
    }
    
    static [void] SetMultilineConnector([string]$open, [string]$middle, [string]$close) {
        [PSPromptConfig]::MultiLineConnector = [Environment]::NewLine
        [PSPromptConfig]::MultiLineConnectorOpenFirstLine = $open
        [PSPromptConfig]::MultiLineConnectorOpenMiddleLine = $middle
        [PSPromptConfig]::MultiLineConnectorOpenLastLine = $close
    }

    static [void] SetSpaceBetweenItemSeparators([int]$numberOfSpaces, [string]$terminalBackgroundColor) {
        [PSPromptConfig]::SpacesBetweenItemSeparators = [ValidateRange(0)]$numberOfSpaces
        [PSPromptConfig]::TerminalBackgroundColor = $terminalBackgroundColor
    }
}

<#
This class refines the configuration attributes from the PSPromptItem DTO into the final properties for PSPrompt.
It's the interface between the end user's input configuration and how that element is represented on the prompt line.
Most of the refinement is either preprocessing (converting colors to ANSI-sequences) or
    enriching meta attributes for formatting, like which group it belongs to or how it's separated from other items.
Goal is to preprocess and submit configs as lean as possible for PSPrompt to minimize runtime calculations for performance.
#> 
class PSPromptTemplate {
    [PSPromptItem]$config = [PSPromptItem]::new()
    [int]$ItemPosition

    PSPromptTemplate([hashtable]$configToAdd) {
        $configToAdd.GetEnumerator() | ForEach-Object {
            try {
                $this.config.($_.Key) = $_.Value
            } catch {
                Write-Warning "Nonexistent property! Prompt config property $($_.Key) with value $($_.Value) could not be found. Was there a typo in the config name? Allowed properties: $(([PSPromptItem]::new() | gm -MemberType Properties ) -join [Environment]::NewLine)"
                Write-Warning $_
                Write-Warning $_.exception.stackstrace
            }            
        }
    }

    [int] GetItemPosition ([SortedDictionary[int,PSPrompt]]$promptConfig) {
        if ( $this.ItemPosition ) {
            if ( $promptConfig[$this.ItemPosition] ) {
                $this.InsertItemPosition($promptConfig)
            }
            return $this.itemPosition
        }
        return ($promptConfig.Keys | Select -Last 1) + 1
    }
    [void] InsertItemPosition([SortedDictionary[int,PSPrompt]]$promptConfig) {
        [int[]]$existingLaterPositions = $promptConfig.Keys | Where { [int]$_ -gt $this.ItemPosition }
        $existingLaterPositions[-1]..$this.ItemPosition | ForEach {
            $promptConfig[ ($_ + 1) ] = $promptConfig[$_]
        }
    }

    # Wrap each group with its beginning and ending marker symbols/strings.
    [void] SetGroupMarkers([SortedDictionary[int,PSPrompt]]$promptConfig) {
        $allGroupIDs = $promptConfig.Values.GroupID | Sort-Object -Unique
        Foreach ( $groupID in $allGroupIDs ) {
            if ( ! [PSPromptConfig]::GroupMarkerMaps.$groupID ) {
                [PSPromptConfig]::AddGroupMarkerMap($groupID)
            }
            
            $keyOfFirstItemInGroup = $promptConfig.Keys | Where { $promptConfig[$_].GroupID -eq $groupID } | Select -First 1 
            $keyOfLastItemInGroup = $promptConfig.Keys | Where { $promptConfig[$_].GroupID -eq $groupID } | Select -Last 1
        
            $this.RemoveExistingGroupMarkers($promptConfig, $keyOfFirstItemInGroup, $keyOfLastItemInGroup, $groupID)
            $this.SetOpenGroupMarker($promptConfig, $keyOfFirstItemInGroup, $groupID)
            $this.SetCloseGroupMarker($promptConfig, $keyOfLastItemInGroup, $groupID)
        }
    }
    
    # Reset the existing group markers, so they can be reapplied with the latest item, 
    # e.g., a new item has been appended, and the group closing marker should be shifted over to the new item.
    [void] RemoveExistingGroupMarkers([SortedDictionary[int,PSPrompt]]$promptConfig, [int]$keyFirstItem, [int]$keyLastItem, [int]$groupID) {
        $groupOpenMarker = [PSPromptConfig]::GroupMarkerMaps.$groupID.open 
        $groupCloseMarker = [PSPromptConfig]::GroupMarkerMaps.$groupID.close
        foreach ( $key in $keyFirstItem..$keyLastItem ) {
            if ( ($promptConfig[$key].BeginningText -replace "`e\[[^m]+m") -eq $groupOpenMarker ) {
                $promptConfig[$key].BeginningText = $promptConfig[$key].PlaceholderBeginningText
            }
            if ( ($promptConfig[$key].EndingText -replace "`e\[[^m]+m") -eq $groupCloseMarker) {
                $promptConfig[$key].EndingText = $promptConfig[$key].PlaceholderEndingText
            }
        }
    }
    
    # OpenGroupMarker is the symbol (or string) that is used to open the group mapped by $groupID in GroupMarkerMaps.
    [void] SetOpenGroupMarker([SortedDictionary[int,PSPrompt]]$promptConfig, [int]$keyFirstItem, [int]$groupID) {
        $itemBGColor = $this.GetbackgroundColorAnsi( $promptConfig[$keyFirstItem].AnsiFormat )
        $markerFGColor = $this.FormatColorAsAnsi($itemBGColor, $false)
        $promptConfig[$keyFirstItem].BeginningText = "`e[0m" + $markerFGColor + [PSPromptConfig]::GroupMarkerMaps[$groupID].open + "`e[0m"
    }
    
    # CloseGroupMarker is the symbol (or string) that is used to close the group mapped by $groupID in GroupMarkerMaps.
    [void] SetCloseGroupMarker([SortedDictionary[int,PSPrompt]]$promptConfig, [int]$keyLastItem, [int]$groupID) {
        $itemBGColor = $this.GetBackgroundColorAnsi( $promptConfig[$keyLastItem].AnsiFormat )
        $markerFGColor = $this.FormatColorAsAnsi($itemBGColor, $false)
        
        $promptConfig[$keyLastItem].EndingText = "`e[0m" + $markerFGColor + [PSPromptConfig]::GroupMarkerMaps[$groupID].close + "`e[0m"
        
        $keyPenultimateItem = $keyLastItem - 1
        $lastItemSeparator = $promptConfig[$keyLastItem].ItemSeparator
        if ( $keyPenultimateItem -gt 0 ) {
            $penultimateItemSeparator = $promptConfig[$keyPenultimateItem].ItemSeparator
            if ( $lastItemSeparator -and $penultimateItemSeparator ) {
                $promptConfig[$keyPenultimateItem].EndingText = $promptConfig[$keyPenultimateItem].EndingText -replace $penultimateItemSeparator, $lastItemSeparator
            }
        }
    }

    [PSPrompt] GetTemplate([SortedDictionary[int,PSPrompt]]$allConfigs){

        # Store all the specified ansi formatting in a separate property. Easier to reference and use later.
        $ansiFormat = & {
            if ( $this.config.AnsiFormat ) {
                $this.config.AnsiFormat
            }
            else {
                $ansiEffects = if ( $this.config.AnsiEffects ) { $this.ResolveAnsiEffects($this.config.AnsiEffects) }
                $fgColor = if ( $this.config.ForegroundColor ) { $this.FormatColorAsAnsi($this.config.ForegroundColor, $false) }
                $bgColor = if ( $this.config.BackgroundColor ) { $this.FormatColorAsAnsi($this.config.BackgroundColor, $true) }
                $fgColor + $bgColor + $ansiEffects
            }
        }

        # The ContentFunction attribute must be coerced into a scriptblock, which is performed here.
        $contentFunction = switch   ($this.config.ContentFunction) {
            {$_ -is [scriptblock]}  {$this.config.ContentFunction}
            {$_ -is [string]}       {[ScriptBlock]::Create($this.config.ContentFunction)}
            DEFAULT {               {$this.config.ContentFunction} } 
        }
        # The final value for Content takes the scriptblock of contentFunction and resolves its output if DoNotRecalculateContentValue is set.
        $content = & {
            if ( $this.config.Content ) {
                $this.config.content
            }
            elseif ($this.config.DoNotRecalculateContentValue) {
                [string]$staticOutput = & $contentFunction
                { $staticOutput }.GetNewClosure()
            }
            else { $ContentFunction }
        }

        # Get the groupID from the group. Mainly, you can specify group as a string, so that it is easy to consistently reference.
        # This block here maps it from the string to the ID, i.e. an integer value.
        # Note the string -> ID mapping is automatically created. Any new strings receive the largest ID + 1 as its mapping.
        $groupID = & {
            if ( $this.config.GroupID ) {
                $this.config.GroupID
            }
            elseif ( $this.config.group ) {
                $group = $this.config.group
                if ( [PSPromptConfig]::MapGroupIDToNames.Values -eq $group ) {
                    [PSPromptConfig]::MapGroupIDToNames.GetEnumerator() | ForEach {
                        if ( $_.Value -eq $group ) {
                            $_.Key
                        }
                    }
                } else { # new string creates a new mapping
                    $latestKey = [PSPromptConfig]::MapGroupIDToNames.Keys | Select-Object -Last 1
                    [PSPromptConfig]::MapGroupIDToNames.Add( ($latestKey + 1), $group )
                    $latestKey + 1
                }
            }
            else {
                0
            }
        }

        # Variables used for defining $this.ItemPosition ahead
        $previousItemKey = $allConfigs.Keys | Select-Object -Last 1
        $allGroupIDs = @($allConfigs.Values.GroupID | Sort-Object -Unique)
        $previousGroupID = if ( $previousItemKey ) {
            $allGroupIDs[$previousItemKey].GroupID
        }
        # Handle the ItemPosition attribute.
        $this.ItemPosition = & {
            # If a previously added item shares this item's groupID, but the immediately previous item is of a different group,
            # then this item is forcibly appended to the existing items in its group. This reorganizes the output, but the priority is assumed that
            # same groups should be concatenated together (it doesn't make any sense to do it any other way anyways)
            if ( $allGroupIDS -eq $groupID -and (!$previousGroupID -or $previousGroupID -ne $groupID) ) {
                $lastGroupItem = $allConfigs.GetEnumerator | 
                    Where { $_.Value.GroupID -eq $groupID -and $_.Value.LineToPrintOn -eq $this.config.LineToPrintOn } | 
                    ForEach { $_.Key } | 
                    Select-Object -Last 1
                $lastGroupItem + 1
            }
            elseif ( $this.config.ItemPosition ) {
                $this.config.ItemPosition
            }
            # If no ItemPosition was specified, then just take the next available position.
            else {
                $lastItem = $allConfigs.Keys | Select-Object -Last 1
                $lastItem + 1
            }
        }

        # Begin defining the beginning and ending strings. This handles the ItemSeparators.
        # SpacesBetweenItemSeparators requires the beginning string to participate.
        if ( [PSPromptConfig]::SpacesBetweenItemSeparators ) {
            $beginningString = & {
                # add the opening group marker
                if ($this.config.BeginningText) {
                    $this.config.BeginningText
                }
                # Add the itemseparator string to the beginning
                elseif ( $this.config.ItemSeparator -and $this.config.BackgroundColor ) {
                    ' ' * ([PSPromptConfig]::SpacesBetweenItemSeparators - 1) +
                    (
                        $this.GetFormattedItemSeparator(
                            $this.config.ItemSeparator,
                            $this.config.BackgroundColor,
                            $false
                        )
                    )
                }
                elseif ( $this.config.ItemSeparator ) { $this.config.ItemSeparator }
                # skip beginning string if no itemseparator specified
                else {
                    ''
                }
            }
    
            $endingString = & {
                if ( $this.config.EndingText ) {
                    $this.config.EndingText
                }
                elseif ($this.config.ItemSeparator ) {
                    $this.GetFormattedItemSeparator(
                        $this.config.ItemSeparator,
                        $this.config.BackgroundColor,
                        $true
                    )
                }
                else {
                    ''
                }
            }
        }
        else {
            # Add global group opener
            $beginningString = & {
                if ( $this.config.BeginningText ) {
                    $this.config.BeginningText
                }
                elseif ($this.config.ItemSeparator -and $previousItemKey -and $this.config.BackgroundColor ) {
                    $this.GetFormattedItemSeparator(
                        $this.config.ItemSeparator,
                        $this.config.BackgroundColor,
                        $allConfigs[$previousItemKey]
                    )
                }
                elseif ( $this.config.ItemSeparator ) {
                    $this.config.ItemSeparator
                }
                else { '' }
            }
            $endingString = & {
                if ( $this.config.EndingText ) {
                    $this.config.EndingText
                }
                else {
                    ''
                }
            }
        }
        
        return [PSPrompt]@{
            GroupID = $groupID
            AnsiFormat = $ansiFormat
            BeginningText = $beginningString
            RawContent = $this.config.ContentFunction
            Content = $content
            EndingText = $endingString
            PlaceholderBeginningText = $beginningString
            PlaceholderEndingText = $endingString
            ItemSeparator = $this.config.ItemSeparator
        }
    }
    
    [string] ResolveAnsiEffects([AnsiEffectsFlags]$ansiEffects) {
        $strBuilder = [StringBuilder]::new('')
        [AnsiEffectsFlags].GetEnumNames() |
            Where-Object {
                $ansiEffects.HasFlag([AnsiEffectsFlags]::$_)
            } |
            ForEach-Object {
                $strBuilder.Append("`e[$([int][AnsiEffects]$_)m")
            }
        return $strBuilder.ToString()
    }
    [string] ResolveAnsiEffects([string]$ansiEffects) {
        return $ansiEffects
    }

    [string] FormatColorAsAnsi ([string]$color, [bool]$isBackground) {
        $colorRGB = [ColorRGB]::TryParseString($color)
        if (!$colorRGB) {
            return $color
        }
        
        return $colorRGB.ConvertColorRGBToAnsi($isBackground)
    }

    [string] GetFormattedItemSeparator ([string]$wrappingString, [string]$bgColor, [bool]$isEndingString) {
        $backgroundColor = $foregroundColor = ''
        if ( $isEndingString ) {
            $foregroundColor = $this.FormatColorAsAnsi($bgColor, $false)
        }
        else {
            $foregroundColor = $this.FormatColorAsAnsi([PSPromptConfig]::TerminalBackgroundColor, $false)
            $backgroundColor = $this.FormatColorAsAnsi($bgColor, $true)
        }
        return "`e[0m" + $foregroundColor + $backgroundColor + $wrappingString + "`e[0m"
    }
    [string] GetFormattedItemSeparator ([string]$wrappingString, [string]$bgColor, [PSPrompt]$previousItemConfig) {
        $backgroundColor = $foregroundColor = ''
        $previousForegroundColor = $this.GetBackgroundColorAnsi($previousItemConfig.AnsiFormat)
        $foregroundColor = $this.FormatColorAsAnsi($previousForegroundColor, $false)
        $backgroundColor = $this.FormatColorAsAnsi($bgColor, $true)
        
        return "`e[0m" + $foregroundColor + $backgroundColor + $wrappingString + "`e[0m"
    }

    [string] GetBackgroundColorAnsi ([string]$ansiColorString) {
        $rgb = ($ansiColorString -replace '.*\[1;48;2((;[0-9]+){3})m.*', '$1').Trim(';') -split ';' 
        
        $red = $rgb[0]
        $green = $rgb[1]
        $blue = $rgb[2]
        return "$red;$green;${blue}"
    }
}