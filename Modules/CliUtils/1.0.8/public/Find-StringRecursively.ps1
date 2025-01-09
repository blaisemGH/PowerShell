using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Collections.Concurrent
using namespace System.IO

class FindStringDTO {
    [string]$FSRPath
    [string]$LineNo
    [string]$Line
    [Microsoft.PowerShell.Commands.MatchInfoContext]$Context
    [string]$Matches
    [string]$Path
    [string]$Filename
}

class FindStringShortPathDTO {
    [string]$FSRPath
    [string]$LineNo
    [string]$Line
    [Microsoft.PowerShell.Commands.MatchInfoContext]$Context
    [string]$Matches
    [string]$Path
    [string]$Filename
}

<#
    .DESCRIPTION
        This is a wrapper function that combines Get-ChildItem and Select-String into a single function.
        It is intended to emulate the grep command in Unix and is also aliased to grep.
        
        Ultimately after a lot of wrangling with this function, the niche I found for it was in output
        formatting and convience. It is prettier than Select-String and more reponsive to type than
        gci | sls, which feels somehow disruptive to type out after being used to typing a quick grep
        in unix.

    .NOTES
        Hint: Pipe this function into Format-Table -Wrap to avoid truncated output.
        As mentioned above, this function is intended to emulate grep, so the parameters Path and Pattern
        are switched in position like Unix grep (`grep <pattern> <path>`).

#>
Function Find-StringRecursively {
    [CmdletBinding(DefaultParameterSetName='RegExPattern')]
    Param (
        [Parameter(Mandatory, ParameterSetName = 'RegExPattern', Position=0)]
        [Parameter(Mandatory, ParameterSetName = 'SimplePattern', Position=0)]
        [string]$Pattern,

        [Parameter(ValueFromPipeline)]
        [String]$InputObject = '.',

        [Parameter(ValueFromPipelineByPropertyName, Position=1)]
        [alias('PSPath', 'LP')]
        #[IfPathStringTransformToFileSystemInfo()]
        [SupportsWildcards()]
        [object]$Path,

        [Parameter(Mandatory, ParameterSetName = 'RegExNotMatch')]
        [Parameter(Mandatory, ParameterSetName = 'SimpleNotMatch')]
        [string]$NotMatch,

        [Parameter(ParameterSetName = 'RegExPattern')]
        [Parameter(ParameterSetName = 'RegExNotMatch')]
        [switch]$AllMatches,

        [Parameter(ParameterSetName = 'SimplePattern')]
        [Parameter(ParameterSetName = 'SimpleNotMatch')]
        [switch]$SimpleMatch,

        [string]$FilterFile = '*',

        [alias('nr')]
        [switch]$NoRecurse,
        [switch]$Force,
        [switch]$CaseSensitive,
        [int[]]$Context,

        [ArgumentCompleter({
            param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
            (
                [Text.Encoding]::GetEncodings().Name + ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
            ) |    Where-Object {
                $_ -like "$wordToComplete*"
            }
        })]
        [ValidateScript({
            If ($_ -in [Text.Encoding]::GetEncodings().Name -or 
                $_ -in ([Text.Encoding] | Get-Member -Type Property -Static | Select-Object -exp Name)
            ) {
                $true
            }
            Else {
                $err = [ErrorRecord]::new("$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]", $null, 'InvalidArgument', $null)
                $PSCmdlet.ThrowTerminatingError($err)
            }
        })]
        [string]$Encoding,

        [switch]$List,
        [switch]$Quiet,
        [switch]$NoEmphasis,

        # Activate to include binary files.
        [switch]$IncludeBinaryFiles,
        # Limits the file path displayed output to 35 characters (wraps longer filepaths).
        [switch]$ShortenFilePath,

        [Parameter(ParameterSetName = 'RegExPattern')]
        [Parameter(ParameterSetName = 'RegExNotMatch')]
        [switch]$OnlyOutputMatches
    )
    begin {
        $Pattern  = $Pattern -Replace '^([*])$','.$1' # replaces wildcard * to a regex .*, as only regex is allowed.

        # region build [IO.Directory]::GetFiles() and Get-ChildItem params. Get-ChildItem is a fallback if GetFiles() fails.
        $GCIparams = @{'File' = $true}
        $enumerationOptions = [System.IO.EnumerationOptions]::new()
        $AttributesToSkip = @('ReparsePoint')
        If ( !($NoRecurse) ) {
            $enumerationOptions.RecurseSubdirectories = $true
        } else {
            $AttributesToSkip += 'Directory'
        }
        If ( $FilterFile ) {
            $GCIparams.Add( 'Filter' , $FilterFile)
        }
        $binaryFilter = If ( !$IncludeBinaryFiles ) {  
            $AttributesToSkip += 'Compressed'
            '(?<![.]zip|7z|.ar|dll|class|t?gz|exe|iso|a?vhd|sha1|checksum|vm.{0,2}|png|jpe?g|svg|tiff|gif|bmp|lz4|snappy|zstd|nxt)$'
        }
        
        $binaryFilterPattern = [regex]::new($binaryFilter, ('Compiled', 'IgnoreCase'))
        
        $enumerationOptions.AttributesToSkip = $AttributesToSkip
        # end region

        # region build Select-String params
        $SLSparams = @{}
        If ( $Pattern ) {
            $SLSparams.Add( 'Pattern'        , $Pattern)
        }
        If ( $NotMatch ) {
            $SLSparams.Add( 'NotMatch'        , $NotMatch)
        }
        If ( $AllMatches -or $OnlyOutputMatches ) {
            $SLSparams.Add( 'AllMatches'    , $true)
        }
        If ( $SimpleMatch ) {
            $SLSparams.Add( 'SimpleMatch'    , $SimpleMatch)
        }
        If ( $CaseSensitive ) {
            $SLSparams.Add( 'CaseSensitive' , $CaseSensitive)
        }
        If ( $Context ) {
            $SLSparams.Add( 'Context' , $Context)
        }
        If ( $Encoding ) {
            $SLSparams.Add( 'Encoding'    , $Encoding)
        }
        If ( $List ) {
            $SLSparams.Add( 'List'    , $true)
        }
        If ( $Quiet ) {
            $SLSparams.Add( 'Quiet'    , $true)
        }
        # end region 

        $ansi = [char]27
        $ansiOrange  = "$ansi[38;5;202m"
        $ansiYellow  = "$ansi[93m"
        $ansiReset   = "$ansi[0m"
        $ansiReverse = "$ansi[7m"
        $ansiReverseOff = "$ansi[27m"
        $ansiStrikeOff  = "$ansi[29m"
        $ansiStrike     = "$ansi[9m"
        
        $noFileSLSInput = [List[string]]@()
    }
    process {
        $SLSInputFromFileObject = [ConcurrentDictionary[string,int]]@()

        if ($Path) {
            $Path | ForEach-Object -ThrottleLimit 4 -Parallel {
                try {
                    $fullPath = Convert-Path $_ -ErrorAction Stop
                
                    [string[]]$subFolderfileList = try {
                        [IO.Directory]::GetFiles( $fullPath, $FilterFile, $enumerationOptions )
                    } catch {
                        (Get-ChildItem -LiteralPath $fullPath @GCIParams -Recurse:(!$NoRecurse) -Force:$Force -Attributes !ReparsePoint).FullName
                    }

                    try {
                        if ( $binaryFilter ) {
                            $subFolderfileList.Where({ $_ -and $binaryFilterPattern.Match($_).Success }).ForEach({
                                $null = $SLSInputFromFileObject.TryAdd($_, 0 )
                            })
                        } else {
                            $subFolderfileList.ForEach({
                                $null = $SLSInputFromFileObject.TryAdd($_, 0)
                            })
                        }
                    } catch [ArgumentNullException] {}
                } catch [Management.Automation.ItemNotFoundException] {
                    $noFileSLSInput.Add($_)
                }
            }
            $subFolderfileList = $null
        }
        else {
            foreach ($inputItem in $InputObject) {
                $noFileSLSInput.Add($inputItem)
            }
        }

        # Run Select-String for file objects. Raw text is handled in the end block.
        Foreach ( $item in $SLSInputFromFileObject.Keys ) {

            # Last param building for Select-String and output as a relative filepath.
            If ( $Path ) {
                $SLSParams.LiteralPath = $item
                $filePath = Resolve-Path -LiteralPath $item -Relative
            }

            try {
                Select-String @SLSparams -ErrorAction Stop | ForEach-Object { 
                    If ( $Quiet ) {
                        $_
                    }
                    Else {
                        If ( $Context ) {
                            # Get the right lines to display in the output when Select-String's -Context parameter is used.
                            # By default, the preceding and succeeding lines are output with an offset, especially if
                            # the span of context lines overlaps with another match. Both the offset and overlap are handled here.
                            $preCount = try {@($_.Context.DisplayPreContext -split "`r?`n").Count } catch { $_.Context.DisplayPostContext.Count }
                            $preLineNumber = ''
                            $postCount = try {@($_.Context.DisplayPostContext -split "`r?`n").Count } catch { $_.Context.DisplayPostContext.Count }
                            $postLineNumber = ''
                            If ( $preCount ) {
                                ForEach ($LineNumber in $preCount..1) {
                                    $preLineNumber += ($_.LineNumber - $LineNumber).ToString() + "`n"
                                }
                            }
                            If ( $postCount ) {
                                ForEach ($LineNumber in 1..$postCount) {
                                    $postLineNumber += "`n" + ($_.LineNumber + $LineNumber).ToString()
                                }
                            }
                        }
                        
                        # handle empty context attributes, such as if the parameter isn't selected.
                        if ( !($displayPreContext = $_.Context.DisplayPreContext | Out-String) ) { $displayPreContext = '' }
                        if ( !($displayPostContext = $_.Context.DisplayPostContext | Out-String) ) { $displayPostContext = '' }

                        # Implement emphasis highlighting here.
                        $formattedLineOutput = & {
                            if ( $OnlyOutputMatches ) {
                                $_.Matches.Value
                            }
                            elseif ($NoEmphasis) {
                                $_.Line
                            }
                            # For Select-String outputs with -Context, which are multiline with the form
                            # .*><filename>:<line number>:<preContext><line><postContext>
                            # This regex captures all of that and keeps only <line>.
                            elseif ($_.ToEmphasizedString($_.line) -match 
                                '(?s).*(?-s)> .*:[0-9]+:(?<line>.+)\n?(?s).*'
                            ) {
                                $Matches.line
                            }
                            # Filter Select-String's output of <filename>:<linenumber>:<line> to just <line>
                            else {
                                $_.ToEmphasizedString($_.line) -replace ('>? ?' + ([regex]::Escape($_.Path + ':' + $_.LineNumber))  + ':')
                            }
                        }
                        # The output for file input                    
                        $out = @{
                            FSRPath = $ansiOrange + $filePath + $ansiReset
                            LineNo  = $preLineNumber + $ansiYellow + $_.LineNumber + "$ansiReset" + $postLineNumber
                            Line = '{0}{1}{2}{3}' -f $displayPreContext,
                                $formattedLineOutput,
                                "`n",
                                $displayPostContext -replace "`r?`n$"
                            Context = $_.Context
                            Matches = $_.Matches
                            Path = $filePath
                            Filename = Split-Path $filepath -Leaf
                        }

                        if ( $ShortenFilePath ) { [FindStringShortPathDTO]$out }
                        else {[FindStringDTO]$out}
                    }
                }
            } catch [ArgumentException] {
                Write-Error "$($_.Exception)"
            } catch { Write-Debug $_ }
        }
    }
    end {
        if ( !$Path ) {
            if ( $OnlyOutputMatches ) {
                return $noFileSLSInput |
                    Select-String @SLSParams |
                    Select-Object -ExpandProperty Matches |
                    Select-Object -ExpandProperty Value
            }
            $noFileSLSInput | Select-String @SLSParams
        }
    }
}