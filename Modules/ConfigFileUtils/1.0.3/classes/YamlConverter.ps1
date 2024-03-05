using namespace System.Collections.Generic
using namespace System.Text.RegularExpressions

<#
    This class is used to parse yaml config files and import them into PowerShell as PS Objects.
    The parsing is performed line-by-line, converting:
        YAML dictionaries into a PS type. This type is determined by the input argument to the constructor--default is a PSCustomObject.
        YAML lists into a PS array via wrapping in '@()'
    The class monitors the current indentation of each line.
        Indented lines prompt the opening of a new dictionary or array.
        Outdented lines prompt the closing of a dictionary or array.

    The current indentation and dictionary "type" are each stored in separate stacks, being popped or pushed as the indentation changes.

    The parser DOES NOT support advanced YAML syntaxes, e.g., YAML code such as anchors.
#>

Class YamlConverter {
    [list[string[]]]$yamlCode = @()
    [string]$outType = '[PSCustomObject]@{'
    [string]$outTypeRegex = '\[PSCustomObject\]@\{'

    [int]$lineCount = 0
    [int]$debugInputLineCount = 0
    [hashtable]$debugMapInputLineCount = @{}
    [int]$previousIndentCount = 0

    [stack[string]]$indentTracker = [Stack[string]]@()
    [stack[string]]$markerTypeTracker = [Stack[string]]@()

    [bool]$isNewDocument = $true
    [string]$documentCloser
    [int]$firstLineNumber

    [string]$indentType
    [string]$indentTypeName
    [string]$replaceDash
    
    [string]$lineIndentation
    [string]$lineContent

    [int]$indentCount
    [string]$indentPeek

    [bool]$isNotArrayElement

    [string]$lineKeyPreFormat
    [string]$lineKey
    [string]$lineValue
    [string]$previousLineValue = 'first line placeholder' # required to not be empty at the start for one of the control flows.
    static [string]$uniqueMarker = ' ' + [string][char]0x2561 * 3
    static [Regex]$regexUniqueMarker = ([Regex]::new([YamlConverter]::uniqueMarker, 'Compiled'))

    YamlConverter([string[]]$inputYamlContents ) {
        $cleanedYamlCode = [YamlFormatter]::new($inputYamlContents).Format_RawYamlCode()
        Foreach ( $yamlDoc in $cleanedYamlCode ) {
            $this.yamlCode.Add($yamlDoc)
        }
    }
    YamlConverter([string[]]$inputYamlContents, [bool]$outAsHashTable ) {
        $cleanedYamlCode = [YamlFormatter]::new($inputYamlContents).Format_RawYamlCode()
        Foreach ( $yamlDoc in $cleanedYamlCode ) {
            $this.yamlCode.Add($yamlDoc)
        }
        
        If ( $outAsHashTable ) {
            $this.outType = '@{'
            $this.outTypeRegex = '@\{'
        }
    }

    # Closes any remaining outdents.
    [string[]] Complete_CurrentYamlDocument() {
        return $(
            ForEach ( $collection in $this.markerTypeTracker.ToArray().Clone() ) {
                Write-Output $this.Close_Outdent()
            }
        )
    }

    # Starts each document, either at the top of a file or separated with '---'
    # Required because a YAML can start with either a dictionary type or a list type, which requires a different opening logic.
    [string] Initialize_NextYamlDocument([string]$line) {
        $this.firstLineNumber = $this.lineCount
        $this.isNewDocument = $false
        if ( !$this.indentType ) {
            $openingMarker = $this.outType
            $this.markerTypeTracker.Push($openingMarker)
            $this.indentTracker.Push('')
        }
        else {
            $this.isNotArrayElement = $true
            $openingMarker = $this.Write_NewIndent($line)
        }
        $this.Update_DebugInputLineMap($line)
        return '{0}{1}' -f $openingMarker, [Environment]::NewLine
    }

    # Performed when '---' is found to demarcate a boundary between YAML files.
    [string] Switch_YamlDocument() {
        $this.isNewDocument = $true
        $this.previousIndentCount = 0
        $this.indentCount = 0
        $this.previousLineValue = 'first line placeholder'
        return $this.Complete_CurrentYamlDocument()
    }

    [string[]] Convert_YamlToPS([string[]] $yamlDoc) {
        Return $(
            ForEach ( $line in $yamlDoc ) {
                $this.lineCount += 1
                $this.Update_DebugInputLineMap($line)
 
                    # Defines whether space or tab indentation and uses this for the rest of the document.
                    If ( !$this.indentType -and $line -match '^[-\s]') {
                        $this.Set_IndentationStyle($line)
                    }
                    ElseIf ( $this.indentType -and $line -match '^\s' -and $line -notmatch "^$($this.indentType)") {
                        Throw "Document identified first indent uses $($this.indentTypeName) indentation, but current line indentation does not. Please use consistent indentation characters on line $($this.lineCount)"
                    }
                    if ( $line -match '^#' ) {
                        Write-Output $line
                        continue
                    }
                    
                    # Separates the line between indentation and text for future parsing.
                    $this.Split_CurrentLine($line)
                    
                    # The start of a new document must proceed after Split_CurrentLine, as this method extracts the current indentation.
                    # This is because if a YAML document begins with a list, the current indentation needs to be pushed to the indent tracker.
                    if ( $this.isNewDocument ) {
                        Write-Output $this.Initialize_NextYamlDocument($line)
                    }

                    # Defines the level of indentation on this line and the previous line for indentation comparisons later.
                    $this.Set_IndentationStatus()
                    # Extract the key and value of this line, or if it's a list, only the value.
                    # Keys containing certain special characters and string-values are force-wrapped in quotes.
                    $this.Set_CurrentLineKeyValuePair()
                    
                    # Some Yaml files don't define a value for their key, even though they are not a dictionary.
                    # PowerShell can't parse a hashtable/object with a key that has no value. This method inserts an empty value.

                    If ( ($this.indentCount -le $this.previousIndentCount -and $this.indentType -or ( !$this.indentpeek -and $this.indentCount -eq 0 -and !$this.indentType) -and (! $this.previousLineValue -or $this.previousLineValue -match '^\s*#') )) {
                        Write-Output "''"
                        $this.Update_DebugInputLineMap($this.previousLineValue)
                    }

                    # Save the value or list element for the next line.
                    $this.Save_KeyValueOrListElement()

                    # After parsing the key and value above, the final output line is prepared as <key = value>.
                    # List elements are wrapped in quotes.
                    $outputLine = $this.Get_LineTextToPrint($line)

                    # Check for and handle outdents by closing any remaining open nested collections.
                    If ( $this.indentCount -lt $this.previousIndentCount -and $this.indentTracker.Count -gt 0) {
                        Write-Output ($this.Write_NewOutdent())
                    }
                    # Check for and handle indents by opening a new collection (list or dictionary)
                    ElseIf ( $this.indentCount -gt $this.previousIndentCount -and $this.LineCount -ne $this.firstLineNumber ) {
                        Write-Output ($this.Write_NewIndent($line))
                    }
    
                    # If the current line in the YAML file is part of a list of dictionaries, then
                    # close the dictionary and open a new dictionary without closing the list.
                    if ( $continueListOfDict = $this.Write_NextDictIfOpenDictList($line) ){
                        Write-Output $continueListOfDict
                    }

                    # After all the collection markers have been output above (open list, close list, open dict, close dict, etc.)
                    # output the YAML line itself here in PS syntax.
                    Write-Output $outputLine
                    $this.Update_DebugInputLineMap($line)
            }
            if ( $this.lineKey -and !$this.lineValue ) {
                Write-Output "''"
                $this.Update_DebugInputLineMap($this.previousLineValue)
            }
            Write-Output $this.Switch_YamlDocument()
        )
    }
    
    [void] Set_IndentationStyle ([string]$line) {
        $testLine = $line -replace '^-(.*)', '$1'
        If ( $testLine -match '^\t' ) {
            $this.indentType        = ([char]9).ToString()
            $this.indentTypeName    = 'tab'
            $this.replaceDash       = ''
        }
        Elseif ( $testLine -match '^ ' ) {
            $this.indentType        = ([char]32).ToString()
            $this.indentTypeName    = 'space'
            $this.replaceDash       = ' '
        }
    }

    [void] Split_CurrentLine ( [string]$line ) {
        $this.lineIndentation = (($line -replace '^(\s*)-(\s)',"`$1$($this.replaceDash)`$2") -split '[^\s]')[0]
        $this.lineContent = & {
            If ( $this.lineIndentation ) {
                (($line -replace '^(\s*)-(\s)',"`$1$($this.replaceDash)`$2") -split $this.lineIndentation, 2)[1]
            }
            Else {
                $line
            }
        }
    }

    [void] Set_IndentationStatus () {
        If ($this.indentType) {
            $this.indentCount = ($this.lineIndentation -split $this.indentType).Count - 1
        }
        Else {
            $this.indentCount = 0
        }

        # Assemble useful variables for handling indents and outdents below.
        If ( $this.indentTracker.Count -eq 0 ) {
            $this.indentPeek = $null
            $this.previousIndentCount = 0
        }

        Else {
            $this.indentPeek = $this.indentTracker.Peek()
            $this.previousIndentCount = ($this.indentPeek -split $this.indentType).Count - 1
        }
    }

    [void] Set_CurrentLineKeyValuePair () {
        $this.isNotArrayElement = $false

        $this.Set_CurrentLineKey()
        $this.Set_CurrentLineValue()
    }
        
    [void] Set_CurrentLineKey () {
        # Build Matches variable. The regex matches lines of the form <'key': >, <"key": >, <key: >
        $Matches = $null
        [void]($this.lineContent -match '^([''][^''\s]*['']|["][^"\s]*["]|[^''"\s]+):( .*|\s*)$')

        $this.lineKeyPreFormat = & {
            If ( $Matches ) {
                (($Matches[0] -split ':')[0] -replace '([^\s]+):(?:([\\ ]|[\\ ][\\ ]))(.*)','$1 = $2').Trim('\ ')
            }
            # when there is no regex match, i.e., it's a <- "list element"> line, skip the key.
            Else {
                $null
            }
        }

        # Wraps the key in single quotes if the key contains a -, _, /, or . and there aren't already quotes in the key name.
        $this.lineKey =  $this.lineKeyPreFormat -replace '^([^''"]?[^''"]*[-_./:][^''"]*)$', '''$1'''
    }
    
    [void] Set_CurrentLineValue () {
        # Extracts the value, and if the value is a []-enclosed list, replace it with PS-array syntax.
        $lineContentValueRaw = ($this.lineContent -split '(?<!^((''[^'']+)|("[^"]+))): ', 2)[1] -replace '^\[(.*)\]$', '@($1)'
        $value = $lineContentValueRaw -replace '(?<!^((''[^'']+)|("[^"]+)))\s*#.*'
        $this.lineValue = & {
            # The | is YAML code to denote a here-string value. This has no meaning for this class, as it converts multi-line to singleline. Skips this line.
            if ( $value -match '^\s*#') {
                $value
            }
            # Wrap single quotes on the value if it's not an int or float, i.e., is to be treated as a non-empty string. Existing single quotes are escaped.
            ElseIf ( $value -and $value -isnot [int] -and $value -isnot [double]) {
                $value -replace "(['])", "''" -replace '^(.*)$', '''$1'''
            }
            Else {
                $value
            }
        }
    }
    
    [void] Save_KeyValueOrListElement() {
        If ( $this.lineKey ) {
            If ( $this.lineValue -eq $this.lineContent ) { #If the line is a kv-pair, yet the value and original line are all the same, something went wrong.
                Throw "Cannot parse key:value pair. Attempt to separate left and right of the colon yielded the same value as the original line. Line $($this.lineCount)"
            }

            # Define that this line is not a list element for future steps.
            $this.isNotArrayElement = $true
            $this.previousLineValue = $this.lineValue
        }
        else {
            $this.previousLineValue = $this.lineContent
        }
    }

    # Assemble output line to print at the end of line processing (after the indentations have been adjusted for)
    [string] Get_LineTextToPrint([string]$line) {
        # If line is key-value pair, output the line in PowerShell syntax:
        If ( $this.lineKey ) {
            Return $this.lineIndentation + $this.lineKey + ' = ' + $this.lineValue
        }
        # For all lines that aren't kv-pairs, i.e., list elements, ensure they are wrapped in quotes:
        Else {
            # Remove the leading - and any leading whitespace before the strings
            $removeDashLine = ($line -replace '^\s*-\s*').Trim()

            # If already wrapped in ' or ", don't change anything:
            If ( $removeDashLine -match '^[''"].*[''"]$' ) {
                return $this.lineIndentation + $removeDashLine
            }
            # If there are no quotes anywhere, wrap the element in single quotes.
            ElseIf ( $removeDashLine -notmatch '[''"]' ) {
                return $this.lineIndentation + "'" + $removeDashLine + "'"
            }
            # If there are quotes inside but it's not wrapped by quotes, then escape any single quotes and force wrap in single quotes
            Else {
                return $this.lineIndentation + ($removeDashLine -replace "(['])", "''" -replace '^(.*)$', '''$1''')
            }
        }
    }

    [string] Close_Outdent () {
        [void]$this.indentTracker.Pop()

        # Extract the proper indendation. A pure aesthetic inclusion in case debugging of the PS-syntax is needed.
        $closeIndentPeek = & {
            If ( $this.indentTracker.Count -gt 0 ) {
                $this.indentTracker.Peek()
            }
            Else {
                $null
            }
        }

        # Checks the current marker type and closes it with the appropriate closing syntax.
        $closeOutdentMarker = & {
            Switch ( $this.markerTypeTracker.Peek() ) {
                '@('    { $closeIndentPeek + ')' }
                "$($this.outType)"    { $closeIndentPeek + '}' }
                "@($($this.outType)"    { $closeIndentPeek + '})' }
            }
        }

        [void]$this.markerTypeTracker.Pop()
        $this.Update_DebugInputLineMap($null)
        Return $closeOutdentMarker
    }

    [string[]] Write_NewOutdent () {
        # Throw error if the script run out of indents --> something must be off with the indentation
        If ( $this.indentTracker.Count -eq 0 ) {
            Throw "Indentation not in alignment with previous lines! Line $($this.lineCount)"
        }

        # Loop through all the possible outdents, since yaml files can outdent multiple levels from one line to the next.
        Return $(
            While ( $this.indentTracker.Count -gt 0 -and $this.lineIndentation -ne $this.indentTracker.Peek() ) {
                $this.Close_Outdent()
            }
        )
    }
    
    [string] Write_NewIndent ([string]$line) {
        [void]$this.indentTracker.Push($this.lineIndentation)
        $this.Update_DebugInputLineMap($line)

        # For non-list lines, simply push the new indentation.
        If ( $line -notmatch '^\s*-' ) {
            $this.markerTypeTracker.Push("$($this.outType)")
            return $this.indentPeek + $this.markerTypeTracker.Peek()
        }

        # For list lines (contain -) that require opening a new list, check if it's opening a new dictionary or a list.
        Else {
            # Open list of dictionaries (or nested lists)
            If ( $this.isNotArrayElement ) {
                $this.markerTypeTracker.Push("@($($this.outType)")
                return $this.indentPeek + $this.markerTypeTracker.Peek()
            }
            # Open list of primitive values
            Else {
                $this.markerTypeTracker.Push('@(')
                return $this.indentPeek + '@('
            }
        }
    }
    
    [string] Write_NextDictIfOpenDictList ([string]$line) {
        # If line starts with '-', the current indentation has an open list of dictionaries, the current line is a kv pair,
        # is not a primitive value, is either an outdent or of the same line, and it's not the first line of the file...
        If (
            $line -match '^\s*-' -and
            $this.markerTypeTracker.count -gt 0 -and
            $this.markerTypeTracker.Peek() -match "^@\($($this.outTypeRegex)" -and
            $this.isNotArrayElement -and
            $this.indentCount -le $this.previousIndentCount -and
            $this.lineCount -ne $this.firstLineNumber
        ) {
            $this.Update_DebugInputLineMap($null)
            Return $this.indentPeek + "};$($this.outType)" # close list element of key-value pairs and open new list element of kv pairs.
        }
        Else {
            Return $null
        }
    }
    [void]Update_DebugInputLineMap ($inputLine) {
        $this.debugInputLineCount += 1
        $this.debugMapInputLineCount[$this.debugInputLineCount] = @($this.lineCount, $inputLine)
    }

    [list[object]] Import_YamlCode () {
        $output = [List[object]]@()
        $count = 0
        Foreach ($yamlDoc in $this.yamlCode) {
            $parsedCode = $this.Convert_YamlToPS($yamlDoc)
            Write-Debug 'Outputting post processing format'
            Write-Debug ($parsedCode -join [Environment]::NewLine)
            try {
                $output.Add((Invoke-Expression ($parsedCode -join [Environment]::NewLine)))
            }
            catch [System.Management.Automation.ParseException] {
                $exceptionLineNumber = $_.ToString() -replace '.*line:([0-9]+)(?:.|\n)*', '$1'
                $minimumExceptionLineNumber = [Math]::Max(1, $exceptionLineNumber - 50)
                $maximumExceptionLineNumber = [Math]::Min($parsedCode.Count, $exceptionLineNumber + 10)
                $maximumDebugLineNumber = [Math]::Min($this.debugMapInputLineCount.Count, $exceptionLineNumber + 100)
                $inputFileLineNumber = $this.debugMapInputLineCount[($exceptionLineNumber -as [int])][0]
                $inputFileLineValue = $minimumExceptionLineNumber..$maximumDebugLineNumber | ForEach { $this.debugMapInputLineCount[$_][1] } | select -unique -last 20
                $outputLineValue = ($minimumExceptionLineNumber - 1)..($maximumExceptionLineNumber) | ForEach { $parsedCode[$_] }
                throw "Error in doc $count while parsing input yaml code on line $inputFileLineNumber. This number is the first outdent after the erroroneous line.
                    Last 20 lines of received input around the line of error:
                    $($inputFileLineValue | Out-String)
                    Last 50 lines of obtained output around the line of error:
                    $($outputLineValue | Out-String)
                    PowerShell exception message:
                    $_
                "
            }
            catch [System.Management.Automation.ParameterBindingException] {
                $err = [System.Management.Automation.ErrorRecord]::new(
                    "The YamlCode in document $count returned an empty output. Check that it contains valid yaml and isn't completely commented out.", $null, 'InvalidData', $null
                )
                throw $err
            }
            catch {
                Write-Debug 'outputting pre-processing format'
                Write-Debug ($yamlDoc | Out-String)
                Throw "Error while parsing yaml document $count. Activate `$DebugPreference = Continue to see whole file. Reported error: $_"
            }
            $count += 1
        }
        return $output
    }
}
