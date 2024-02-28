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

    The parser DOES NOT support advanced YAML syntaxes, i.e., YAML code such as anchors.
#>

Class YamlUtils {
    [string[]]$yamlCode
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

    static [string]$smartQuotesForRegexMatch = (
        ([psobject].Assembly.GetType('System.Management.Automation.Language.SpecialChars').DeclaredFields.
            Where{ $_.Name -like 'Quote*'}.GetValue($null), '"', "'" | Write-Output
        ) -join '|'
    )
    <#
        The parser relies on a single line containing a key-value pair or array element to identify valid yaml syntax.
        Multi-line values are not part of the parser logic, so they must be first flattened to a single-line value.
        The below regex identifies multi-line values in the yaml code, and in the constructor they are joined into a single line.
        Explanation of regex:
            '(' + [Environment]::NewLine + '|\n)+^\s*   -->  a series of empty lines plus a line beginning with arbitrary whitespace
            (?!     --> After the arbitrary whitespace, the line must not continue with either:
                --- (i.e., starting a new YAML document)
            or
                \s* --> arbitrary whitespace followed by 1 of:
                    - .+            --> a YAML list element
                    [^:\s]+:\s*     --> a YAML key (string containing no whitespace) without a value, e.g., opening a new dictionary
                    [^:\s]+: .+     --> a YAML key (string containing no whitespace) followed by a space and value
                                            (permits the syntax <text:text> which could be a valid string)
                    #+.*            --> any line containing a comment.
        All of these conditions imply a new YAML object, and not a multistring value.
        Anything not fitting these conditions is treated as part of a multi-line string.
    #>
    static [Regex] $joinMultiLineValuesToSingleLine = ([Regex]::new(
        '(' + [Environment]::NewLine + '|\n)+^\s*(?!\s*(---\s*|\{\{.*|- .+|[^:\s]+:\s*|[^:\s]+: .+|#+.*)$)',
        ('Multiline', 'Compiled')
    ))
    # Similar to above. Some YAML files start a multi-line string with an opening quote as the key value and then a newline.
    # This regex identifies such a line and is used to remove the newline after the opening quote.
    static [Regex] $joinQuotedMultiLineValuesToSingleLine = ([Regex]::new(
        '(?<=:\s*(["][^"]+|[''][^'']+))(' + [Environment]::NewLine + '|\n)+\s*',
        ('Compiled')
    ))

    <#
        The above regex is used to replace the newlines in a multiline value (see its description).
        The replacement for the newline is a rare unicode character, 0x2561, repeated 3 times, which means it should be safe as a unique marker.
        This unique marker is used to tell the parser to increment its line count by 1 to reflect the fact the original input yaml code spanned multiple lines.
        The parser tracks the exact line number of the input yaml code for debugging, so that errors output the line number for the user to easily find and fix.
    #>
    static [string]$uniqueMarker = ' ' + [string][char]0x2561 * 3
    static [Regex]$regexUniqueMarker = ([Regex]::new([YamlUtils]::uniqueMarker, 'Compiled'))

    YamlUtils([string[]]$inputYamlContents ) {
        $this.yamlCode = $this.Format_InputYamlCode($inputYamlContents)
    }
    YamlUtils([string[]]$inputYamlContents, [bool]$outAsHashTable ) {    
        $this.yamlCode = $this.Format_InputYamlCode($inputYamlContents)
        
        If ( $outAsHashTable ) {
            $this.outType = '@{'
            $this.outTypeRegex = '@\{'
        }
    }
    [string[]] Format_InputYamlCode ( [string[]]$yamlCode ) {
        return (
            $yamlCode -join [Environment]::NewLine -replace
            [YamlUtils]::joinMultiLineValuesToSingleLine, [YamlUtils]::uniqueMarker -replace
            [YamlUtils]::joinQuotedMultiLineValuesToSingleLine, [YamlUtils]::uniqueMarker -replace
            [YamlUtils]::smartQuotesForRegexMatch, "'" -split
                [Environment]::NewLine
        )
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
        return $this.Complete_CurrentYamlDocument()
    }

    [string[]] Parse() {
        Return $(
            ForEach ( $rawLine in $this.yamlCode ) {
                $this.lineCount += 1
                $this.Update_DebugInputLineMap($rawLine)

                # Move to next document if line is --- and it's not the first line. Else if line is --- and it's first line, skip.
                if ( $rawLine -match '^---' -and $this.indentType) {
                    Write-Output ($this.Switch_YamlDocument())
                    continue
                }
                elseif ( $rawLine -match '^---' ) {
                    continue
                }
                elseif ( $rawLine -match '^(?<indentation>\s*)(?<goLangCode>\{\{.*}}[#\s]*)$' ) {
                    Write-Output "# skip goLangCode: $rawLine"
                    <#
                    Write-Output $( Switch ( $this.markerTypeTracker.Peek() ) {
                        '@('    { $Matches.indentation + $Matches.goLangCode -replace "(['])", "''" -replace '^(.*)$', '''$1''' }
                        "$($this.outType)"    { $Matches.indentation + 'goTemplateCode' + $this.lineCount + ' = ' + ($Matches.goLangCode -replace "(['])", "''" -replace '^(.*)$', '''$1''') }
                        "@($($this.outType)"    { $Matches.indentation + "};$($this.outType)" }
                    })
                    #>
                    continue
                }

                # Replaces any multiline values with a single space-delimited string.
                $line = if ( $countAllMatches = [YamlUtils]::regexUniqueMarker.Matches($rawLine).Count ){
                    $this.lineCount += $countAllMatches
                    $rawLine -replace [YamlUtils]::uniqueMarker, ' '
                }
                else {
                    $rawLine
                }
 
                # Skip lines that are empty or commented out
                If ( $line -match '[\S]' -and $line -notmatch '^[\s]*#' ) {
                    # Defines whether space or tab indentation and uses this for the rest of the document.
                    If ( !$this.indentType -and $line -match '^[-\s]') {
                        $this.Set_IndentationStyle($line)
                    }
                    ElseIf ( $this.indentType -and $line -match '^\s' -and $line -notmatch "^$($this.indentType)") {
                        Throw "Document identified first indent uses $($this.indentTypeName) indentation, but current line indentation does not. Please use consistent indentation characters on line $($this.lineCount)"
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
                    If ( $this.indentCount -le $this.previousIndentCount -and $this.indentType -and (! $this.previousLineValue -or $this.previousLineValue -match '^\s*#')) {
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
                    $this.Update_DebugInputLineMap($rawLine)
                }
            }
            if ( $this.lineKey -and !$this.lineValue ) {
                Write-Output "''"
                $this.Update_DebugInputLineMap($this.previousLineValue)
            }
            Write-Output $this.Complete_CurrentYamlDocument()
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
            If ( $value -in '|','|-' ) {
                ''
            }
            elseif ( $value -match '^\s*#') {
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

    [object] Import_RawYamlCode () {
        $parsedCode = $this.Parse()
        Write-Debug ($parsedCode -join [Environment]::NewLine)
        try {
            return Invoke-Expression ($parsedCode -join [Environment]::NewLine)
        }
        catch [System.Management.Automation.ParseException] {
            $exceptionLineNumber = $_.ToString() -replace '.*line:([0-9]+)(?:.|\n)*', '$1'
            $minimumExceptionLineNumber = [Math]::Max(1, $exceptionLineNumber - 50)
            $maximumExceptionLineNumber = [Math]::Min($parsedCode.Count, $exceptionLineNumber + 10)
            $maximumDebugLineNumber = [Math]::Min($this.debugMapInputLineCount.Count, $exceptionLineNumber + 200)
            $inputFileLineNumber = $this.debugMapInputLineCount[($exceptionLineNumber -as [int])][0]
            $inputFileLineValue = $minimumExceptionLineNumber..$maximumDebugLineNumber | Foreach { $this.debugMapInputLineCount[$_][1] } | select -unique -last 20
            $outputLineValue = ($minimumExceptionLineNumber - 1)..($maximumExceptionLineNumber) | Foreach { write-host $_; $parsedCode[$_] }
            throw "Error parsing input yaml code on line $inputFileLineNumber. This number is the first outdent after the erroroneous line.
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
                "The YamlCode returned an empty output. Check that it contains valid yaml and isn't completely commented out.", $null, 'InvalidData', $null
            )
            Write-Error $err
            throw
        }
    }
}
