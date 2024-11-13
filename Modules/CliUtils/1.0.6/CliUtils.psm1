using namespace System.Management.Automation

# cd has been redefined to pushd.
If ( [System.Environment]::OSVersion.Platform -notmatch 'unix' -and [System.Environment]::OSVersion.Platform -match 'Win' ) {
	Set-Alias -Name cd -Value Push-Location -Scope Global -Option AllScope
}
Else {
	Set-Alias -Name pd -Value Push-Location -Scope Global -Option AllScope
}
Set-Alias -Name bd		-Value Back-Dir					-Scope Global -Option AllScope

Set-Alias -Name fhash	-Value Out-FileHash				-Scope Global -Option AllScope

Set-Alias -Name gd		-Value Get-Dir					-Scope Global -Option AllScope

Set-Alias -Name lock	-Value Start-LockThread			-Scope Global -Option AllScope
Set-Alias -Name unlock	-Value Stop-LockThread			-Scope Global -Option AllScope

Set-Alias -name net		-value Get-NetTCPConnection		-Scope Global -Option AllScope

Set-Alias -name graph	-value Out-AllMembersAsGridView	-Scope Global -Option AllScope
Set-Alias -Name gt		-Value Use-GitCliForBranch		-Scope Global -Option AllScope

Set-Alias -Name b64		-Value Convert-Base64			-Scope Global -Option AllScope
Set-Alias -Name sop		-Value Search-ObjectProperties  -Scope Global -Option AllScope
Set-Alias -Name sov		-Value Search-ObjectValues		-Scope Global -Option AllScope
Set-Alias -Name slp		-Value Select-Property	    	-Scope Global -Option AllScope
Set-Alias -Name slop	-Value Select-Property  	   	-Scope Global -Option AllScope

Set-Alias -Name count		-Value Measure-CollectionCount 	-Scope Global -Option AllScope
Set-Alias -Name joinop		-Value Invoke-JoinOperator		-Scope Global -Option AllScope
Set-Alias -Name matchop		-Value Invoke-MatchOperator     -Scope Global -Option AllScope
Set-Alias -Name replaceop	-Value Invoke-ReplaceOperator   -Scope Global -Option AllScope
Set-Alias -Name splitop		-Value Invoke-SplitOperator     -Scope Global -Option AllScope

Set-Alias -Name gis		-Value Get-ItemSize				    -Scope Global -Option AllScope
Set-Alias -Name fsr	    -Value Find-StringRecursively	    -Scope Global -Option AllScope
Set-Alias -Name rs		-Value Replace-StringInFile		    -Scope Global -Option AllScope
Set-Alias -Name clip	-Value Set-Clipboard		 	    -Scope Global -Option AllScope

if ( $env:OS -match 'Windows' ) {
    Set-Alias -Name du		-Value Get-ItemSize				-Scope Global -Option AllScope
    Set-Alias -Name find	-Value Find-FileRecursively		-Scope Global -Option AllScope
    Set-Alias -Name grep	-Value Find-StringRecursively	-Scope Global -Option AllScope
    Set-Alias -name sed 	-value Replace-StringInFile		-Scope Global -Option AllScope
    Set-Alias -Name base64	-Value Convert-Base64			-Scope Global -Option AllScope
}

# Defines a Function equivalent to Unix's 'cd -'. We set the alias to 'cd-' for PowerShell.
Function cd- {
	Push-Location (Get-Location -stack).Path[0]
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

<#
if ( (Get-PSReadLineKeyHandler -Chord Tab).Function -eq 'MenuComplete' ) {

	function TabExpansion2 {

	    [CmdletBinding(DefaultParameterSetName = 'ScriptInputSet')]
	    [OutputType([Management.Automation.CommandCompletion])]
	    param (
	        [Parameter(ParameterSetName = 'ScriptInputSet', Mandatory, Position = 0)]
	        [AllowEmptyString()]
	        [string] $inputScript,

	        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 1)]
	        [int] $cursorColumn = $inputScript.Length,

	        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 0)]
	        [Language.Ast] $ast,

	        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 1)]
	        [Language.Token[]] $tokens,

	        [Parameter(ParameterSetName = 'AstInputSet', Mandatory, Position = 2)]
	        [Language.IScriptPosition] $positionOfCursor,

	        [Parameter(ParameterSetName = 'ScriptInputSet', Position = 2)]
	        [Parameter(ParameterSetName = 'AstInputSet', Position = 3)]
	        [Hashtable] $options = $null
	    )

	    $completions = if ($PSCmdlet.ParameterSetName -eq 'ScriptInputSet') {
	        [CommandCompletion]::CompleteInput(
	            <#inputScript#>  #$inputScript,
	            <#cursorColumn#> #$cursorColumn,
	            <#options#>      #$options
<#	        )
	    } else {
	        [CommandCompletion]::CompleteInput(
	            <#ast#>              #$ast,
	            <#tokens#>           #$tokens,
	            <#positionOfCursor#> #$positionOfCursor,
	            <#options#>          #$options
<#	        )
	    }

		$completions.CompletionMatches = switch ($completions.CompletionMatches.Count) {
			1 { if ( $completions.CompletionMatches.ResultType -eq [CompletionResultType]::ProviderContainer ) { $completions.CompletionMatches + '/'; break } else {$completions.CompletionMatches} }
			0 { ''; break }
			DEFAULT { $completions.CompletionMatches}
		}

		return $completions | Write-Output
	}
}
#>
if ( $env:OS -match 'Windows' ) {
	Write-Host @"

Some sample functions / aliases that were been added.

	$bullet   gfs/du                         du -sh from linux
	$bullet   grep                           grep -ir from linux. Note shares parameters with Select-String and GCI.
	$bullet   rs/sed                         Use to replace strings in files. Use -Fast to reduce console output and gain speed.
	$bullet   net                            alias for Get-NetTCPConnection, the PowerShell version of netstat (but easier)
	$bullet   .. = cd ..                     ... = cd ../.. | .... = cd ../../.. | ..... = cd ../../../.. | etc.
	$bullet   cd-                            `cd -` from Linux (back one dir)
	$bullet   bd <n>                         take you back n directory changes, e.g., popd (cd has been remapped to pushd).

	Run `help <function>` for more info, or help about_CliUtils for a full list of functions.
"@
}