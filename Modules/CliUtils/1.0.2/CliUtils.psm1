# Defines a Function equivalent to Unix's 'cd -'. We set the alias to 'cd-' for PowerShell.
Function cd- {
	Push-Location (Get-Location -stack).Path[0]
}

# cd has been redefined to pushd.
If ( [System.Environment]::OSVersion.Platform -notmatch 'unix' -and [System.Environment]::OSVersion.Platform -match 'Win' ) {
	Set-Alias -Name cd -Value Push-Location -Scope Global -Option AllScope
}
Else {
	Set-Alias -Name pd -Value Push-Location -Scope Global -Option AllScope
}
Set-Alias -Name bd		-Value Back-Dir					-Scope Global -Option AllScope

Set-Alias -Name fhash	-Value Out-FileHash				-Scope Global -Option AllScope


Set-Alias -Name gis		-Value Get-ItemSize				-Scope Global -Option AllScope
Set-Alias -Name rs		-Value Replace-StringInFile		-Scope Global -Option AllScope

Set-Alias -Name gd		-Value Get-Dir					-Scope Global -Option AllScope

Set-Alias -Name lock	-Value Start-LockThread			-Scope Global -Option AllScope
Set-Alias -Name unlock	-Value Stop-LockThread			-Scope Global -Option AllScope

Set-Alias -name net		-value Get-NetTCPConnection		-Scope Global -Option AllScope

Set-Alias -name graph	-value Out-AllMembersAsGridView	-Scope Global -Option AllScope
Set-Alias -Name gb		-Value Use-GitCliForBranch		-Scope Global -Option AllScope

Set-Alias -Name b64		-Value Convert-Base64			-Scope Global -Option AllScope

if ( $env:OS -match 'Windows' ) {
    Set-Alias -Name du		-Value Get-ItemSize				-Scope Global -Option AllScope
    Set-Alias -Name find	-Value Find-FileRecursively		-Scope Global -Option AllScope
    Set-Alias -Name grep	-Value Find-StringRecursively	-Scope Global -Option AllScope
    Set-Alias -name sed 	-value Replace-StringInFile		-Scope Global -Option AllScope
    Set-Alias -Name base64	-Value Convert-Base64			-Scope Global -Option AllScope
}

# Faster backtracking up directory trees
Function .. 		{ Push-Location ..							}
Function ...		{ Push-Location ../..						}
Function ....		{ Push-Location ../../..					}
Function .....		{ Push-Location ../../../..					}
Function ...... 	{ Push-Location ../../../../..				}
Function .......	{ Push-Location ../../../../../..			}
Function ........	{ Push-Location ../../../../../../..		}
Function .........	{ Push-Location ../../../../../../../..		}
$bullet = [char]::ConvertFromUtf32(0x2022)
Write-Host @"

The following functions / aliases have been added (Note tab completion is available for all commands and parameters to quickly browse):

	$bullet   Out-FileHash                   #prints the hash of a file. Provide algorithm of your choice, e.g., md5 or SHA256 (use tab completion)
		PS>fhash file.txt -Algorithm SHA256 

	$bullet   du                             #similar to du -sh from linux
	$bullet   grep                           #similar to grep -ir from linux. Note shares parameters with Select-String and GCI.
	$bullet   find                           #similar to find from linux
	
            PS>find <path> <name> [-file, -f] [-directory, -d] [-maxDepth, -depth, -md]

	$bullet   net                            #alias for Get-NetTCPConnection, the PowerShell version of netstat (but easier)
	
            PS>net -LocalPort 8080

	$bullet   sed                            #Use to replace strings in files (alias = rs). Use -Fast to reduce output and gain speed.
	
            PS>sed -oldPattern <string to replace> -newPattern <string to insert> -path <path> -recurse [-includeCommentedLines, -i]

	$bullet   Get-Dir                             #alternative to ls with readable sizes. -tree displays a hierarchy. -NoRecurse available.
            PS>gd * [-noRecurse] [-noDirSize] [-noCalcSize] [-Depth]  # noDirSize = faster. noCalcSize = no dir or file size (fastest)

	$bullet   graph                          #Pipe in an object to graph, and it will output a tabular view with all attributes

	$bullet   .. = cd ..                     #... = cd ../.. | .... = cd ../../.. | ..... = cd ../../../.. | etc.
	$bullet   cd-                            #similar to `cd -` from Linux (back one dir)
	$bullet   bd <n>                         #take you back n directory changes, e.g., popd (cd has been remapped to pushd).

"@