using namespace System.Management.Automation.Language
using namespace System.Management.Automation
using namespace System.Collections.Generic
using namespace System.Collections
<#Parsing properties for gcloud configure

    

    sections:
        5 spaces
    
    properties
        9 spaces
    
    enums
        valid values are
            followed by: (no further indent)+ developer -
        legal values are
            followed by: (no further indent)+ 'if_fast_else_fail' - 
        If true (is bool)
        prop name starts with max_ or contains interval = int

    core section is optional
    #>

class GCloudCompletions {
    static [string]$CompletionFilepath
    static [object]$CompletionTree

    static [IEnumerable[CompletionResult]] GetCompletedArg( [CommandAst] $commandAst, [string] $wordToComplete) {
        #if ( ![GCloudCompletions]::CompletionTree ) {
        #    [GCloudCompletions]::ImportCompletionTree()
        #}
        $resultSet = [HashSet[CompletionResult]]::new()

        [Queue[string]]$gcloudTokens = $commandAst.CommandElements | Where { $_ -notmatch '^gcloud' }
        $currentCliTreeLevel = $global:testgcloud.clone()#[GCloudCompletions]::CompletionTree.Clone()
        
        $token = $null
        while ( $gcloudTokens.Count -gt 0 ) {
            $token = $gcloudTokens.Dequeue()
            if ( $currentCliTreeLevel -is [PSCustomObject] -and $currentCliTreeLevel.ContainsKey($token) ) {
                $currentCliTreeLevel = $currentCliTreeLevel.$token
            }
        }

        $completionArgs = $currentCliTreeLevel.PSObject.Properties.Name | Where { $_ -like "$wordToComplete*" }
        $commands = $completionArgs | Where { $_ -notmatch '^--' } | Sort-Object
        $flags = $completionArgs | Where { $_ -match '^--' } | Sort-Object
        $commands + $flags | ForEach {
            [void]$resultSet.Add( [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) )
        }
        
        return $resultSet
    }

    static [void] ImportCompletionTree() {
        [GCloudCompletions]::CompletionTree = Get-Content ([GCloudCompletions]::CompletionFilepath) | ConvertFrom-Json -AsHashtable
    }
<#
    static [IEnumerable[CompletionResult]] GetCompletedArg( [CommandAst] $commandAst, [string] $wordToComplete) {
        if ( ![GCloudCompletions]::CompletionTree ) {
            [GCloudCompletions]::ImportCompletionTree()
        }
        $resultSet = [HashSet[CompletionResult]]::new()

        [Queue[string]]$gcloudTokens = $commandAst.CommandElements | Where { $_ -notmatch '^gcloud' }
        $currentCliTreeLevel = [GCloudCompletions]::CompletionTree
        
        $token = $null
        while ( $gcloudTokens.Count -gt 0 ) {
            $token = $gcloudTokens.Dequeue()
            if ( $currentCliTreeLevel -is [PSCustomObject] -and $currentCliTreeLevel.PSObject.Properties.Name -Contains $token) {
                $currentCliTreeLevel = $currentCliTreeLevel.$token
            }
        }

        $completionArgs = $currentCliTreeLevel.PSObject.Properties.Name | Where { $_ -like "$wordToComplete*" }
        $commands = $completionArgs | Where { $_ -notmatch '^--' } | Sort-Object
        $flags = $completionArgs | Where { $_ -match '^--' } | Sort-Object
        $commands + $flags | ForEach {
            [void]$resultSet.Add( [CompletionResult]::new($_, $_, [CompletionResultType]::ParameterValue, $_) )
        }
        
        return $resultSet
    }

    static [void] ImportCompletionTree() {
        [GCloudCompletions]::CompletionTree = Get-Content ([GCloudCompletions]::CompletionFilepath) | ConvertFrom-Json
    }
#>
}

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
            foreach ( $coreProperties in $propertyCompletions.'core/'.GetEnumerator() ) {
                $this.CompletionTree.config.$configCommand.Add($coreProperties.Key, $coreProperties.Value)
            }

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
#Register-ArgumentCompleter -CommandName gcloud -ScriptBlock $sbGcloudCompletion 