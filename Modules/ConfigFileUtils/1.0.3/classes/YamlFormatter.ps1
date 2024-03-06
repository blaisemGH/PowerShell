using namespace System.Collections.Generic
using namespace System.Text

# This class is a required complement to the YamlConverter class. It reformats raw yaml code into a suitable input for parsing by YamlConverter.
class YamlFormatter {
    [string[]]$inputYaml
    [string]$multilineBeginsWithQuote
    [string]$multilineBeginsWithPipe
    [bool]$currentlyInMultiline
    [string]$currentLineValue
    [StringBuilder]$collectMultiline
    [stack[string]]$outputLine = @()
    [string]$savedIndentation

    static [Regex]$Test_IsNewYamlDocument = [Regex]::new( '(?m)^---', 'Compiled' )
    static [Regex]$Test_SkipLine = [Regex]::new( '^(\s*#|\s*$)', 'Compiled' )
    static [Regex]$Test_IsLineKV = [Regex]::new( '^\s*(- )?[^\s]+:($| .+$)', 'Compiled' )
    static [Regex]$Test_IsLineListElement = [Regex]::new( '^\s*- \S', 'Compiled' )
    static [Regex]$FindIndentation = [Regex]::new( '^(\s*).*', 'Compiled' )
    static [Regex]$RemoveIndentation = [Regex]::new( '^\s*(.*)', 'Compiled' )
    static [Regex]$RemovePipe = [Regex]::new( '^(\s*\S+:) \|-?\s*(.*)', 'Compiled' )
    static [Regex]$FindValueFromKeyValuePair = [Regex]::new( '^\s*[^:\s]+: ?\s*(.*)', 'Compiled' )
    static [Regex]$FindValueFromListElement = [Regex]::new( '\s*- ', 'Compiled' )
    static [Regex]$FindQuotedMultiline = [Regex]::new( '^([''"])?(?!.*\1\s*$).*', 'Compiled' )
    static [Regex]$FindPipedMultiline = [Regex]::new( '^([|])?.*', 'Compiled' )
    static [Regex]$FindMultiLineGoLangTemplateCode = [Regex]::new( '^\s*\{\{(.*(\n|' + [Environment]::NewLine + '))*?.*}}(\s+|\s*#.*)?', 'Compiled' )
    static [Regex]$FindGoLangTemplateCode = [Regex]::new( '^(?<indentation>\s*)(?<goLangCode>\{\{.*}}[#\s]*)$', 'Compiled' )

    static [string]$UniqueMarker = ' ' + [string][char]0x2561 * 3
    static [string]$smartQuotesForRegexMatch = (
        ([psobject].Assembly.GetType('System.Management.Automation.Language.SpecialChars').DeclaredFields.
            Where{ $_.Name -like 'Quote*'}.GetValue($null), '"', "'" | Write-Output
        ) -join '|'
    )

    YamlFormatter([string[]]$inputYaml) {
        $this.inputYaml = $inputYaml -replace [YamlFormatter]::smartQuotesForRegexMatch, "'"
    }

    # The workhorse method to format everything. All the remaining methods are children of this.
    [List[string[]]]Format_RawYamlCode() {
        $collectionOfYamlDocs = $this.Split_YamlDocuments()
        $output = [List[string[]]]@()
        ForEach ($yamlDoc in $collectionOfYamlDocs) {
            $output.Add($this.Join_MultilineValues(($yamlDoc -join [Environment]::NewLine -replace [YamlFormatter]::FindMultiLineGoLangTemplateCode -split [Environment]::NewLine)))
        }
        return $output | Where {$_}
    }

    # If a yaml input contains multiple documents (lines of '---'), split the input to individual yaml documents for easier parsing.
    [List[string[]]]Split_YamlDocuments() {
        $outputSeparatedYamlFiles = [List[string[]]]@()
        # Join into a single string temporarily, so that it can be split into individual yaml documents. The return will undo this join on each Yaml document.
        $yamlAsSingleString = $this.inputYaml -join [Environment]::NewLine
        $yamlAsSingleString -split [YamlFormatter]::Test_IsNewYamlDocument | Where {$_ -and $_ -ne [Environment]::NewLine} | ForEach {
            $outputSeparatedYamlFiles.Add(($_ -split [Environment]::NewLine))
        }
        return $outputSeparatedYamlFiles
    }

    # Identify all multi-line strings and join them into a single-line string. This vastly simplifies parsing.
    [string[]] Join_MultilineValues ([string[]]$singleYamlDoc) {
        return $(
            foreach ( $line in $singleYamlDoc ) {
                # Skip lines that are empty/only whitespace or whose first non-whitespace character is a comment.
                if ( $line -match [YamlFormatter]::Test_SkipLine ) {
                    continue
                }
                elseif ( $line -match [YamlFormatter]::FindGoLangTemplateCode ) {
                    "# skip goLangCode: $line"
                    continue
                }
                $isLineKV = $this.Test_IsLineKV($line)
                $isLineListElement = $line -match [YamlFormatter]::Test_IsLineListElement
#write-host "$line is key: $isLineKV or le: $isLineListElement"
                #  Handle the case where we are inside a multi-line string.
                if ( $this.currentlyInMultiline ) {
                
                    $newIndentation = [Regex]::Replace($line, [YamlFormatter]::FindIndentation, '$1')
                    $isIndented = $newIndentation.Length -gt $this.savedIndentation.Length

                    # Close a multiline string if the line matches its closing quote.
                    if ( $this.multilineBeginsWithQuote -and $line -match "(?<![\\])$($this.multilineBeginsWithQuote)\s*(#.*)?$" ) {
                        $this.Merge_MultilineValue($line)
                        $this.Close_Multiline()
#write-host "closing quote on $line" -fore green
                        continue
                    }
                    # If the multiline string isn't delimited by quotes, then it MUST end by virtue of being a kv pair that is not indented.
                    elseif ( !$this.multilineBeginsWithQuote -and !$isIndented -and $isLineKV ) {
                        $this.Close_Multiline()
                    }
                    # For every other scenario, add the line and skip to the next line.
                    else {
#write-host "adding line $line" -fore yellow
                        $this.Add_MultilineValue($line)
                        continue
                    }
                }

                # Handle lines that are kv pairs or list elements
                if ( $isLineKV -or $isLineListElement ){
                    $this.savedIndentation = [Regex]::Replace($line, [YamlFormatter]::FindIndentation, '$1')
                    $lineValue = $this.Get_CurrentLineValue($line, $isLineListElement)
                    # Check if it is opening a new multiline value and populate the properties accordingly.
                    if ($this.Test_IsStartOfMultiline($lineValue)) {
                        $this.initialize_Multiline($line)
                    }
                    # If it is not a new multiline value, then simply output the current line.
                    else {
                        # Note the outputLine is withheld for 1 line, i.e., when we print a line (pop it here), it is the line from the previous iteration of the loop.
                        # Reason why: Some multi-line string values are not preceded by quotes or pipes. For these lines, it is only possible to identify that it is a multi-line string *after* the first line where it starts. In this case, we need to concatenate the multi-line string with the first line value. For this reason, we need the previous line value saved, so we can concatenate to it, and not yet output.
                        if ( $this.outputLine.Count -gt 0) {
                            $this.outputLine.Pop()
                        }
                        $this.outputLine.Push($line)
                    }
                }
                # If the line isn't a kv pair, list element, a comment, or empty, then it is deduced that the previous line opened a multi-line string without a quote or pipe. Need to retroactively initialize the multiline string.
                else {
#write-host $line -fore magenta
                    $initialLine = if ( $this.outputLine.Count -gt 0) { $this.outputLine.Pop()} else { '' }
                    $this.Initialize_Multiline($initialLine)
                    $this.Add_MultilineValue($line)
                }
            }
            if ( $this.outputLine.Count -gt 0 ) {
                $this.outputLine.Pop()
            }
            if ( $this.currentlyInMultiline ) {
                $this.Close_Multiline()
            }
        )
    }

    [string] Get_CurrentLineValue ([string]$line, [bool]$isListElement) {
        if ( $isListElement ) {
            return [Regex]::Replace($line, [YamlFormatter]::FindValueFromListElement, '$1')
        }
        else {
            
            return [Regex]::Replace($line, [YamlFormatter]::FindValueFromKeyValuePair, '$1')
        }
    }

    [bool] Test_IsLineKV ($line) {
        $lineNoIndent = [Regex]::Replace($line, [YamlFormatter]::RemoveIndentation, '$1')
        $firstCharInLine = $lineNoIndent[0]
        $closingCharInLine = switch ($firstCharInLine) {
            '{' { '}' }
            '[' { ']' }
            '(' { ')' }
            '"' { '"' }
            "'" { "'" }
            default { 'none found' }
        }
        $notmatch = if ( $closingCharInLine -ne 'none found') {
            $line -notmatch "^\s*$firstCharInLine.*$closingCharInLine\s*$" 
        } else {$true}
        return $notmatch -and $line -match [YamlFormatter]::Test_IsLineKV
    }

    [bool] Test_IsStartOfMultiline ([string]$lineValue) {
        $this.multilineBeginsWithQuote = [Regex]::Replace($lineValue, [YamlFormatter]::FindQuotedMultiline, '$1')
        $this.multilineBeginsWithPipe = [Regex]::Replace($lineValue, [YamlFormatter]::FindPipedMultiline, '$1')
        if ( $this.multilineBeginsWithQuote -or $this.multilineBeginsWithPipe ) {
            return $true
        } else {
            return $false
        }
    }

    [void]Initialize_Multiline([string]$line) {
#Write-Host "adding line $line" -fore yellow
        $lineNoPipe = [Regex]::Replace($line, [YamlFormatter]::RemovePipe, '$1 $2')
        $this.currentlyInMultiline = $true
        $this.collectMultiline = [StringBuilder]::new($lineNoPipe + [Environment]::NewLine)
    }
    [void] Add_MultilineValue([string]$line) {
        $lineNoIndent = $line -replace [YamlFormatter]::RemoveIndentation, '$1'
        $this.collectMultiline.AppendLine($lineNoIndent)
    }
    [void] Merge_MultilineValue([string]$line) {
        $lineNoIndent = $line -replace [YamlFormatter]::RemoveIndentation, '$1'
        $this.collectMultiline.Append($lineNoIndent)
    }
    [string[]]Close_Multiline() {
        $this.multilineBeginsWithQuote = $null
        $this.multilineBeginsWithPipe = $null
        $this.currentlyInMultiline = $false

        $multiLineString = $this.ConvertFrom_StringBuilder()
        $this.collectMultiline = $null

        if ( $this.outputLine.Count -gt 0 ) {
            return @($this.outputLine.Pop()) + $multiLineString
        }
        else {
            return $multiLineString
        }
    }
    [string]ConvertFrom_StringBuilder() {
        return ($this.collectMultiline.ToString() -split [Environment]::NewLine | where {$_}) -join ' '
    }
}