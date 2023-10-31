using namespace System.Collections.Generic

# This class is used to parse yaml config files and import them into PowerShell as PS Objects

Class YamlUtils {
    [string[]]$yamlCode
	[string]$outType = '[PSCustomObject]@{'
	[string]$outTypeRegex = '\[PSCustomObject\]@\{'

    [int]$lineCount = 0
    [int]$previousIndentCount = 0

    [stack[string]]$indentTracker = [Stack[string]]@()
    [stack[string]]$collectionTracker = [Stack[string]]@()

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

	<#
		The Parse method in this class, which is the main workhorse logic behind reading the yaml file, processes yaml input line-by-line, so it requires single-line values. A key-value (kv) pair must not have a value that spans multiple lines.
		
		This occurs, e.g., in the kubernetes .kube file after running `kubectl config view`. Certain string values can span multiple lines for no reason even though they belong to a single key.
		
		In the constructors below is a -replace operator that converts such multi-line values into single-line values.
		
		The goal is to only match multi-line strings of the form "<indent?><key>: foo<newline><indent?>bar", where "foo bar" is a single string value to <key> that has been entered in the yaml file to span multiple lines, and <indent?> refers to arbitrary indentation (including no indentation). The Regex pattern should match the portion "<newline><indent?>" and replace it with a single whitespace, turning the multi-line string value into a single-line string value for the Parse method.

		To explain the regex in detail, the regex pattern is a multi-line pattern (?m) that checks for 1 or more newlines which are followed by 0 or more spaces/tab characters (\s*), and then looks ahead (?!=...) to check the subsequent characters are NOT:
			1. Pattern '- \S+', i.e., a dash followed by a space and then non-space characters, as this would indicate a list element in yaml.
			2. Pattern '[^:]+:\s*', i.e., any characters followed by a colon and 0 or more whitespace, as this would indicate a new dictionary in yaml.
			3. Pattern '[^:]+: \S+', i.e., any characters followed by a colon, then a space, and then non-space characters, as this would indicate a kv pair in yaml.
		Summarized, the regex should not match a line followed by new list elements, new dictionaries, or kv pairs in the yaml file. It is assumed that any other scenario would be a multi-line string and therefore should be concatenated into a single-line value.		
	#>
	YamlUtils([string[]]$inputYamlContents ) {	
		$this.yamlCode = $inputYamlContents -join [Environment]::NewLine -replace (
			'(?m)((' + [Environment]::NewLine + ')|(\n))+\s*(?!((- \S+)|([^:]+:\s*(' + [Environment]::NewLine + ')|(\n))|([^:]+: \S+)))'
		), ' ' -split [Environment]::NewLine
	}
	YamlUtils([string[]]$inputYamlContents, [bool]$outAsHashTable ) {	
		$this.yamlCode = $inputYamlContents -join [Environment]::NewLine -replace (
				'(?m)((' + [Environment]::NewLine + ')|(\n))+\s*(?!((- \S+)|([^:]+:\s*(' + [Environment]::NewLine + ')|(\n))|([^:]+: \S+)))'
			), ' ' -split [Environment]::NewLine
		If ( $outAsHashTable ) {
			$this.outType = '@{'
			$this.outTypeRegex = '@\{'
		}
	}

    [string[]] Parse() {
        Return $(
            Write-Output ('{0}{1}{2}' -f "$($this.outType)", [Environment]::NewLine, [Environment]::NewLine)
            ForEach ( $line in $this.yamlCode ) {
                $this.lineCount += 1

                If ( $line -match '[\S]' -and $line -notmatch '^[\s]*#' ) {
                
                    If ( !$this.indentType -and $line -match '^[-\s]') {
                        $this.Set_IndentationStyle($line)
                    }
                    ElseIf ( $this.indentType -and $line -match '^\s' -and $line -notmatch "^$($this.indentType)") {
                        Throw "Document identified first indent uses $($this.indentTypeName) indentation, but current line indentation does not. Please use consistent indentation characters on line $($this.lineCount)"
                    }

					$this.Split_CurrentLine($line)
	
					$this.Set_CurrentLineIndentation()                
					$this.Set_CurrentLineKeyValuePair()
					$this.Test_KeyValueOrListElement()
					$outputLine = $this.Get_LineTextToPrint($line)
	
					If ( $this.indentCount -lt $this.previousIndentCount -and $this.indentTracker.Count -gt 0) {
						Write-Output ($this.Write_NewOutdent())
					}
					ElseIf ( $this.indentCount -gt $this.previousIndentCount ) {
						Write-Output ($this.Write_NewIndent($line))
					}
	
					Write-Output $this.Write_NextDictIfOpenDictList($line)

					Write-Output $outputLine
				}
            }

            ForEach ( $collection in $this.collectionTracker.ToArray().Clone() ) {
                If ($this.indentTracker.Count -eq 0 ) {
                    break
                }
                Write-Output $this.Close_Outdent()
            }

            Write-Output ('{0}{1}{2}' -f [Environment]::NewLine, [Environment]::NewLine, '}')
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
        $this.lineIndentation    = (($line -replace '^(\s*)-(\s)',"`$1$($this.replaceDash)`$2") -split '[^\s]')[0]
        $this.lineContent = & {
            If ( $this.lineIndentation ) {
                (($line -replace '^(\s*)-(\s)',"`$1$($this.replaceDash)`$2") -split $this.lineIndentation)[1]
            }
            Else {
                $line
            }
        }
    }

    [void] Set_CurrentLineIndentation () {
        # Assemble useful variables for handling indents and outdents below.
        If ( $this.indentTracker.Count -eq 0 ) {
            $this.indentPeek = $null
            $this.previousIndentCount = 0
        }
        Else {
            $this.indentPeek = $this.indentTracker.Peek()
            $this.previousIndentCount = ($this.indentPeek -split $this.indentType.ToString()).Count - 1
        }

        If ($this.indentType) {
            $this.indentCount = ($this.lineIndentation -split $this.indentType).Count - 1
        }
        Else {
            $this.indentCount = 0
        }
    }

    [void] Set_CurrentLineKeyValuePair () {
        $this.isNotArrayElement = $false

        $this.Set_CurrentLineKey()
        $this.Set_CurrentLineValue()
    }
        
    [void] Set_CurrentLineKey () {
        $Matches = $null
        
        # Build Matches variable. The regex matches lines of the form <'key': >, <"key": >, <key: >
        [void]([Regex]::Escape($this.lineContent) -match '(^[''][^'']*['']:)|(^["][^"]*["]:)|(^[^''"]+:) ?')
        $this.lineKeyPreFormat = & {
            If ( $Matches ) {
                (($Matches[0] -split ':')[0] -replace '([^\s]+):(?:([\\ ]|[\\ ][\\ ]))(.*)','$1 = $2').Trim('\ ')
            }
            # when there is no regex match, i.e., it's a <- "list element"> line.
            Else {
                $null
            }
        }

        # Adds single quotes if the key contains a -, _, or . and there aren't already quotes in the key name
        $this.lineKey =    $this.lineKeyPreFormat -replace '^([^''"]?[^''"]*[-_.][^''"]*)$', '''$1'''
    }
    
    [void] Set_CurrentLineValue () {
        # Extracts the value, and if the value is a []-enclosed list, replace it with PS-array syntax.
        $value = ($this.lineContent -replace $this.lineKeyPreFormat).Trim(': ') -replace '^\[(.*)\]$', '@($1)'

        $this.lineValue = & {
            # Wrap quotes on the value if it's not an int or float and doesn't already contain any quotes in its string.
            If ( $value -isnot [int] -and $value -isnot [double] ) {
                $value -replace '^([^''"][^''"]*[^''"])$', '''$1'''
            }
            Else {
                $value
            }
        }
    }
	
	[void] Test_KeyValueOrListElement() {
		If ( $this.lineKey ) {
            If ( $this.lineValue -eq $this.lineContent ) { #If the line is a kv-pair, yet the value and original line are all the same, something went wrong.
                Throw "Cannot parse key:value pair. Attempt to separate left and right of the colon yielded the same value as the original line. Line $($this.lineCount)"
            }

            # Define that this line is not a list element for parsing below
            $this.isNotArrayElement = $true
		}
	}

    # Assemble output line to print at the end of line processing (after the indentations have been adjusted for)
    [string] Get_LineTextToPrint([string]$line) {
        # If line is key-value pair...
        If ( $this.lineKey ) {
            Return ( $this.lineIndentation + $this.lineKey + ' = ' + $this.lineValue )
        }

        # For all lines that aren't kv-pairs, i.e., list elements...
        Else {
            # Remove the leading - and any leading whitespace before the strings
            $removeDashLine = ($line -replace '^\s*-\s*').Trim()

            # If the trimmed line element contains ' or ", but the entire string is not wrapped in ' or ", then throw an error. Validates that ' or " have been correctly applied.
            If ( $removeDashLine -NotMatch '^[''"].*[''"]$' -and $removeDashLine -Match '[''"]' ) {
                Throw "Cannot validate line. List element not wrapped in single or double quotes! Line $($this.lineCount)"
            }
            
            Return $(
                If ( $removeDashLine -match '^[''"].*[''"]$' ) {
                    Write-Output $removeDashLine
                }
                ElseIf ( $removeDashLine -notmatch '[''"]' ) {
                    Write-Output ($this.lineIndentation + "'" + $removeDashLine + "'")
                }
            )
        }
    }

    [string] Close_Outdent () {
        [void]$this.indentTracker.Pop()

        $closeIndentPeek = & {
            If ( $this.indentTracker.Count -gt 0 ) {
                $this.indentTracker.Peek()
            }
            Else {
                $null
            }
        }

        $out = & {
            Switch ( $this.collectionTracker.Peek() ) {
                '@('    { $closeIndentPeek + ')' }
                "$($this.outType)"    { $closeIndentPeek + '}' }
                "@($($this.outType)"    { $closeIndentPeek + '})' }
            }
        }
        [void]$this.collectionTracker.Pop()
    
        Return $out
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
        Return $(

            # For non-list lines
            If ( $line -notmatch '^\s*-' ) {
                $this.collectionTracker.Push("$($this.outType)")
                $this.indentPeek + $this.collectionTracker.Peek()
            }

            # For list lines (contain -) that require opening a new list.
            Else {
                # Open list of dictionaries (or nested lists)
                If ( $this.isNotArrayElement ) {
                    $this.collectionTracker.Push("@($($this.outType)")
                    $this.indentPeek + $this.collectionTracker.Peek()
                }
                # Open list of primitives
                ElseIf ( !$this.isNotArrayElement -or $this.collectionTracker.Peek() -notmatch "^@\($($this.outTypeRegex)"){
                    $this.indentPeek + '@('
                    $this.collectionTracker.Push('@(')
                }
                Else {
                    $null
                }
            }
        )
    }
    
    [string] Write_NextDictIfOpenDictList ([string]$line) {
        # If line starts with '-', the current indentation has an open list of dictionaries, the current line is a kv pair, and it's not a new indent...
        If    (
            $line -match '^\s*-' -and $this.collectionTracker.count -gt 0 -and $this.collectionTracker.Peek() -match "^@\($($this.outTypeRegex)" -and
            $this.isNotArrayElement -and $this.indentCount -le $this.previousIndentCount
        ) {
            return $this.indentPeek + "};$($this.outType)" # close list element of key-value pairs and open new list element of kv pairs.
        }
        Else {
            Return $null
        }
    }
}