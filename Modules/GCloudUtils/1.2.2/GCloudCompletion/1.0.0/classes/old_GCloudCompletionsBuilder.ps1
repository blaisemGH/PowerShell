using namespace System.Collections.Generic

class GCloudCompletionsBuilder {
    [object]$RawCliTree
    [hashtable]$CompletionTree

    GCloudCompletionsBuilder([string]$filePathOfGCloudCliTreeExport) {
        $this.RawCliTree = Get-Content $filePathOfGCloudCliTreeExport -Raw | ConvertFrom-Json
    }

    [void]BuildGCloudCompletions(){
        $this.CompletionTree = $this.GetNestedCompletions($this.rawCliTree)
        
        $configPropertyCompletions = [GCloudCompletionsPropertiesBuilder]::new( ((gcloud topic configurations) ))
        $propertyCompletions = $configPropertyCompletions.GetConfigPropertyCompletions()
        
        foreach ($configCommand in ($this.CompletionTree.config.Keys | where {$_ -notmatch '^--'}) ) {
            foreach ( $kvpair in $propertyCompletions.GetEnumerator() ) {
                $this.CompletionTree.config.$configCommand.Add( $kvPair.Key, $kvPair.Value)
            }
            #foreach ( $coreProperties in $propertyCompletions.'core/'.GetEnumerator() ) {
            #    $this.CompletionTree.config.$configCommand.Add($coreProperties.Key, $coreProperties.Value)
            #}

        }
    }

    [void] ExportGCloudCompletions([string]$outputFilepath){
        $this.CompletionTree | ConvertTo-Json -Depth 50 -Compress | Set-Content $outputFilepath
    }

    [hashtable] GetNestedCompletions([object]$cliTreeLevel) {
        $nestedCompletionDict = @{}
        if ( $cliTreeLevel.commands.PSObject.Properties.Name ) {
            foreach ($cmd in $cliTreeLevel.commands.PSObject.Properties.Name ) {
                    $nestedCompletionDict.Add($cmd, $this.GetNestedCompletions($cliTreeLevel.commands.$cmd))
                
            }
        }
        if ( $cliTreeLevel.flags.PSObject.Properties.Name ) {
            foreach ( $flag in $cliTreeLevel.flags.PSObject.Properties.Name) {
                $nestedCompletionDict.Add($flag, '')
            }
        }

        return $nestedCompletionDict
    }
}

class GCloudCompletionsPropertiesBuilder {
    [string[]]$RelevantHelpMenuText
    
    GCloudCompletionsPropertiesBuilder([string[]]$helpMenuToParse) {
        $relevantHelpMenuSection = $helpMenuToParse -join "`n" | Select-String '(?sm)(?<=^AVAILABLE PROPERTIES\n).*\n(?=^NOTES)'
        $this.RelevantHelpMenuText = $relevantHelpMenuSection -split '\n'
    }

    [hashtable] GetConfigPropertyCompletions() {

        $completionDictionary = @{}

        $currentSection = $null
        $currentProperty = $null
        foreach ($line in $this.RelevantHelpMenuText ) {
            switch -regex ($line) {
                '^\s{5}[a-zA-Z0-9]' {
                    $currentSection = $line.Trim()
                    $completionDictionary.Add("$CurrentSection/", @{})
                }
                '^\s{9}[a-zA-Z0-9]' {
                    $currentProperty = $line.Trim()
                    try {
                    $completionDictionary."$currentSection/".Add($currentProperty, [HashSet[string]]::new())
                    } catch {
                        $completionDictionary | out-string
                        $currentSection
                        $currentProperty }
                }
                '^\s{10,}\+ [a-zA-Z0-9_'']+ -' {
                    $enumValue = ($line -split ' - ' | Select-Object -first 1).Trim("' +")
                    [void]$completionDictionary."$currentSection/".$currentProperty.Add($enumValue)
                }
                '^\s{10,}If True,? ' {
                    [void]$completionDictionary."$currentSection/".$currentProperty.Add('True')
                    [void]$completionDictionary."$currentSection/".$currentProperty.Add('False')
                }
            }
        }

        return $completionDictionary
    }
}
<#
$sbGcloudCompletion = {
    param(
        [string]$WordToComplete,
        [CommandAst]$CommandAst,
        [int]$CursorPosition
    )

    [GCloudCompletions]::GetCompletedArg($CommandAst, $WordToComplete)
}

Register-ArgumentCompleter -Native -CommandName gcloud -ScriptBlock $sbGcloudCompletion 

[gcloudCompletions]::CompletionFilepath = 'C:\Users\MullenixJohn\AppData\Roaming\gcloud\cli\output2.json'
#>