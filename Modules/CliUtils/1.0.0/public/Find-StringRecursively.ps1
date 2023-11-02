<#
	.DESCRIPTION
		This is a wrapper function that combines Get-ChildItem and Select-String into a single function. It is intended to emulate the grep command in Unix and is also aliased to grep.
		
		Ultimately after a lot of wrangling with this function, the niche I found for it was in output formatting and convience. It is prettier than Select-String and more reponsive to type than gci | sls, which feels somehow disruptive to type out after being used to typing a quick grep in unix.

		IMPORTANT: Pipe this function into Format-Table in order to wrap the output, so that the line isn't truncated.
		
		Future ideas: Include the Matches property from Select-String. Add a switch to filter out compressed/binary files.
#>
Function Find-StringRecursively {
	[CmdletBinding(DefaultParameterSetName='RegExPattern')]
	Param (
		[Parameter(
			Mandatory=$true,
			ValueFromPipelineByPropertyName=$true,
			ValueFromPipeline,
			Position=1#,
			#ParameterSetName = 'dir'
		)]
		[alias('PSPath')]
		[string]$Path = '.',

		[Parameter(Mandatory=$true, ParameterSetName = 'RegExPattern', Position=0)]
		[Parameter(Mandatory=$true, ParameterSetName = 'SimplePattern', Position=0)]
		[string]$Pattern,

		[Parameter(Mandatory=$true, ParameterSetName = 'RegExNotMatch')]
		[Parameter(Mandatory=$true, ParameterSetName = 'SimpleNotMatch')]
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
			) |	Where-Object {
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
                Throw "$_ is not a valid Encoding given by [System.Text.Encoding]::GetEncodings() or a static property of [System.Text.Encoding]"
            }
        })]
        [string]$Encoding,

		[switch]$List,

		[switch]$Quiet,

		[switch]$IncludeBinaryFiles
	)
	begin {
		$odir = Convert-Path (PWD)
		$Pattern  = $Pattern -Replace '^([*+}])$','.$1' #((?>^|[^.)}[\]]))([*+?])','$1.$2'

		$GCIparams = @{'File' = $true}
		$recurse = & {
			If ( !($NoRecurse) ) {
				'AllDirectories'
			}
			Else {
				'TopDirectoryOnly'
			}
		}
		If ( $FilterFile ) {
			$GCIparams.Add( 'Filter' , $FilterFile)
		}
		$binaryFilter = If ( $IncludeBinaryFiles ) { '^.' } Else { '(?<![.]((zip)|(7z)|(.ar)|(dll)|(class)|(t?gz)|(exe)|(png)|(jpe?g)|(svg)|(tiff)|(gif)|(bmp)))$' }
		$binaryFilterPattern = [regex]::new($binaryFilter, 'Compiled')

		$SLSparams = @{}
		If ( $Pattern ) {
			$SLSparams.Add( 'Pattern'		, $Pattern)
		}
		If ( $NotMatch ) {
			$SLSparams.Add( 'NotMatch'		, $NotMatch)
		}
		If ( $AllMatches ) {
			$SLSparams.Add( 'AllMatches'	, $true)
		}
		If ( $SimpleMatch ) {
			$SLSparams.Add( 'SimpleMatch'	, $SimpleMatch)
		}
		If ( $CaseSensitive ) {
			$SLSparams.Add( 'CaseSensitive' , $CaseSensitive)
		}
		If ( $Context ) {
			$SLSparams.Add( 'Context' , $Context)
			#$contextPointer	= "$ansi[38;5;202m>:$ansi[0m"
			$preContextSkip		= [Environment]::NewLine * $Context[0]
		}
		If ( $Encoding ) {
			$SLSparams.Add( 'Encoding'	, $Encoding)
		}
		If ( $List ) {
			$SLSparams.Add( 'List'	, $true)
		}
		If ( $Quiet ) {
			$SLSparams.Add( 'Quiet'	, $true)
		}
		
		$ansi = [char]27
		$ansiOrange = "$ansi[38;5;202m"
		$ansiYellow = "$ansi[93m"
		$ansiUndo = "$ansi[0m"
		
		$notPath = $false
	}
	process {
		$SLSInput = [Collections.Generic.List[string]]@()
		$path = & {
			If ( $Path -in '*','.' ) {
				$odir
			}
			Else {
				$Path
			}
		}
		If ( Test-Path $path ) {
			$isFilePath = $true
			Foreach ( $fullPath in Convert-Path $path ) {
				try {
					[string[]]$subFolderfileList = [System.IO.Directory]::GetFiles( $fullPath, $FilterFile, $recurse )
				}
				catch {
					[string[]]$subFolderfileList = ( Get-ChildItem -LiteralPath $fullPath @GCIParams -Recurse:(!$NoRecurse) -Force:$Force ).FullName
				}
				$SLSInput.AddRange( [string[]]($subFolderfileList | Where { $binaryFilterPattern.Match($_).Success }) )
			}
			$maxFileLength = [Math]::Min(90, (Measure-Object -InputObject $subFolderfileList -Property length -Maximum).Maximum)
		}
		Else {
			$SLSParams.InputObject = $Path
			$SLSInput.Add($Path)
		}

		Foreach ( $item in $SLSInput ) {
			If ( $isFilePath ) {
				$SLSParams.LiteralPath = $item
			}
			Select-String @SLSparams | ForEach-Object {
				If ( $Context ) {
					$preCount = try {@($_.Context.DisplayPreContext.split([Environment]::NewLine)).Count } catch { $_.Context.DisplayPostContext.Count }
					$preLineNumber = ''
					$postCount = try {@($_.Context.DisplayPostContext.split([Environment]::NewLine)).Count } catch { $_.Context.DisplayPostContext.Count }
					$postLineNumber = ''
					If ( $preCount ) {
						ForEach ($LineNumber in $preCount..1) {
							$preLineNumber += ($_.LineNumber - $LineNumber).ToString() + [Environment]::NewLine
						}
					}
					If ( $postCount ) {
						ForEach ($LineNumber in 1..$postCount) {
							$postLineNumber += [Environment]::NewLine + ($_.LineNumber + $LineNumber).ToString()
						}
					}
				}
				& {
					If ( $isFilePath ) {
						$filePath = Resolve-Path $_.path -Relative
						if ( !($displayPreContext = $_.Context.DisplayPreContext | Out-String) ) { $displayPreContext = '' }
						if ( !($displayPostContext = $_.Context.DisplayPostContext | Out-String) ) { $displayPostContext = '' }
						$emphasizedLine = & {
							if ($_.ToEmphasizedString($_.line) -match '(?s).*(?-s)> .*:[0-9]+:(?<line>.+)(?s).*' ) {
								$matches.line
							}
							else {
								$_.ToEmphasizedString($_.line) -replace ('>? ?' + ([regex]::Escape($_.Path + ':' + $_.LineNumber))  + ':')
							}
						}
						[PSCustomObject]@{
							Filename	= "{0,-$maxFileLength}" -f ($ansiOrange	+	($filePath.substring([math]::max($filePath.Length - 80, 0)))	 +	":$ansiUndo")
							#Line		= '{0,-9}' -f ( $preContextSkip + "$ansi[93m" + $_.LineNumber	+	">$ansi[0m" + $postContextSkip )
							Line		= '{0,-9}' -f ( $preLineNumber + $ansiYellow + $_.LineNumber	+	">$ansiUndo" + $postLineNumber )
							#Contents	= '{0}{1}{2}{3}{4}' -f ($_.Context.PreContext | Out-String), [Environment]::NewLine, ($contextPointer + $_.Line),					[Environment]::NewLine, ($_.Context.PostContext | Out-String) #'{0, -155}' -f $_.Line
							Contents	= '{0}{1}{2}' -f $displayPreContext,
							$emphasizedLine, #-match '(?s).*(?-s)> .*:[0-9]+:(?<line>.+)(?s).*' ('(?s).*' + [environment]::NewLine + '> .*:[0-9]+:([^' + [Environment]::NewLine + ']+).*'), '$1' -replace ('>? ' + ([regex]::Escape($_.Path + ':' + $_.LineNumber))) + ':'),
							$displayPostContext -replace "$([Environment]::NewLine)$" #'{0, -155}' -f $_.Line
						}
					}
					else {
						$_.ToEmphasizedString($_.Line)
					}
				}# | Format-Table -Wrap -HideTableHeaders
			}
		}
	}
}
		#}
		### This is an alternative approach that so far seems slower than the select string cmdlet used above, but maybe on 5-10 million+ line files, or files with tens of thousands of matches, it *might* be faster.
#		Else {
#			class lineMatch {
#
#				[string]$file
#				[int]$line
#				[string]$content
#
#				linematch ( [string]$a, [int]$b, [string]$c ) { 
#					$this.file = $a; $this.line = $b; $this.content = $c
#				}
#			}
#			$regex = [regex]::new($pattern, "Compiled")
#
#			Foreach ( $objFile in (Get-ChildItem -Path $cleanPath @GCIparams -Recurse:$RecurseIfTrue) ) {
#				$filePath = $objFile.FullName
#				$fileName = $objFile.Name
#				$outputList = [System.Collections.Generic.List[object]]::new()
#
#				$lineCount = 0
#				Switch -File $filePath {
#					Default {
#						If ( $regex.Matches($_).Success) {
#							[void]$outputList.Add( [lineMatch]::new($fileName, $lineCount,$_) )
#						}
#						$lineCount += 1
#					}
#				}
#				$outputList | Format-Table -autosize -wrap @{
#					label = 'file name'
#					Expression = { "$ansi[96m$($_.file):$ansi[0m" }
#				}, @{
#					label = 'line'
#					Expression = { "$ansi[93m$($_.line)>$ansi[0m" }
#				}, @{
#					label = 'line contents'
#					Expression = {$_.Content}
#				}
#			}
#		}
#	}
#	Else {
#		Throw "$Path does not exist!"
#	}
#}