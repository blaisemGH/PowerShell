using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Text

Class Kube {
    static [string[]]$ArrayOfApiResources
    static [pscustomobject[]]$FullApiResources
    static [string]$CurrentNamespace
    static [string]$CurrentCluster
    static [HashSet[String]]$SyncNamespacePrefixesToInts = @()
    static [hashtable]$MapIntsToNamespaces = @{}
    static [scriptblock]$AddContext = {
        param($ContextName)
        kubectl config use-context $contextName
    }
    static [hashtable]$MapDefaultApiVersions = @{
        pods = 'v1'
        nodes = 'v1'
        events = 'v1'
    }
    
    static [string] $relevantContainersFile = "$HOME/.pwsh/KubectlUtils/relevantContainers.psd1"
    static [HashSet[string]] $relevantContainers = ( & {
        try {
            return (Import-PowerShellDataFile ([Kube]::relevantContainersFile) -ErrorAction Stop).Values
        } catch {
            Write-Verbose "No relevant containers found. These are used in e.g., `Get-KubeMetrics` to filter a curated list of relevant containers. Checked [kube]::relevantContainersFile for a PowerShellDataFile and found path: $([Kube]::relevantContainersFile)"
            return [HashSet[string]]@($null)
        }
    })

    static [string] $ContextFile = "$HOME/.pwsh/KubectlUtils/contexts.psd1"
    static [string] $ModularContextFile = ""
    static [OrderedDictionary] $MappedContexts
    <#
    static [hashtable] $MapGCloudContexts = ( & {
        try {
            $contexts = Import-PowerShellDataFile ([Kube]::ContextFile)#& { $o = [ordered]@{}; ($ht = Import-PowerShellDataFile $HOME\Documents\tenants\contexts.psd1) | Select -exp Keys | Sort | % { $o.Add($_,$ht[$_])}; $o }
        } catch {
            Write-Verbose "No contextFile map found. This is used by the `Get-KubeContext` function to shortcut access to different contexts. Checked [Kube]::contextFile for a PowerShellDataFile and found path: $([Kube]::contextFile)"
            $contexts = @{}
        }
        $modularContexts = if ( [Kube]::ModularContextFile -and (Test-Path [Kube]::ModularContextFile) ) {
            try {
                Import-PowerShellDataFile ([Kube]::ModularContextFile)
            } catch {
                @{}
            }
        } else { @{} }
        return $contexts + $modularContexts
    })
#>
    static [string[]] Get_APIResourceList() {
        If ( [Kube]::ArrayOfApiResources ) {
            return [Kube]::ArrayOfApiResources
        }
        Else {
			[Kube]::Initialize_KubeApiAutocomplete($false)
            return [Kube]::ArrayOfApiResources
        }
    }
    static [object] Import_APIResourceList() {
        return (
            kubectl api-resources -o wide | Select-Object -skip 1 |
                Foreach-Object {
                    Write-Output -NoEnumerate ($_ -replace 
                    '^ *' -replace 
                    '^(\S+)\s+(\S)(?<=.{50,})' , '$1  $2' -replace
                    ' {3,}' , ' ' -split ' ') | Select-Object @{
                        label = 'NAME'
                        expression = { $_[0] }
                    }, @{
                        label = 'SHORTNAME'
                        expression = { $_[1] }
                    }, @{
                        label = 'APIVERSION'
                        # The api here returns strings like, e.g., for pods, 'metrics.k8s.io/v1beta1', or 'v1'. The /v1beta1 and v1 are useless.
                        # The actual string should be 'pods.metrics.k8s.io' for the first apiversion, or just 'pods' for the v1 apiversion.
                        # In other words, I can preemptively clean any APIVERSION of '/ + <string>' or any APIVERSION without a / entirely.
                        expression = { if ( $_[2] -match '/' ) { ( $_[2] -split '/' )[0] } }
                    }, @{
                        label = 'NAMESPACED'
                        expression = { $_[3] }
                    }, @{
                        label = 'KIND'
                        expression = { $_[4] }
                    }, @{
                        label = 'VERBS'
                        expression = { $_[5] -split ',' }
                    }, @{
                        label = 'CATEGORIES'
                        expression = { $_[6] -split ',' }
                    }, @{
                        label = 'DEFAULTAPIVERSION'
                        expression = { if ( $_.Name -and [Kube]::MapDefaultApiVersions.ContainsKey($_.Name) ) { [Kube]::MapDefaultApiVersions.$($_.Name) } }
                    }
                }
        )
        
        <#
        $apiResources = kubectl api-resources -o wide | Select-Object -skip 1 |
            Foreach {
                Write-Output -NoEnumerate ($_ -replace 
                '^ *' -replace 
                '^(\S+)\s+(\S)(?<=.{50,})' , '$1  $2' -replace
                ' {3,}' , ' ' -split ' ') | Select-Object @{
                    label = 'NAME'
                    expression = { $_[0] }
                }, @{
                    label = 'SHORTNAME'
                    expression = { $_[1] }
                }, @{
                    label = 'APIVERSION'
                    expression = { $_[2] } }
                }, @{
                    label = 'NAMESPACED'
                    expression = { $_[3] }
                }, @{
                    label = 'KIND'
                    expression = { $_[4] }
                }, @{
                    label = 'VERBS'
                    expression = { $_[5] -split ',' }
                }, @{
                    label = 'CATEGORIES'
                    expression = { $_[6] -split ',' }
                }
            }
        
        return $apiResources | Select-Object NAME, SHORTNAME, @{
                # The api here returns strings like, e.g., for pods, 'metrics.k8s.io/v1beta1', or 'v1'. The /v1beta1 and v1 are useless.
                # The actual string should be 'pods.metrics.k8s.io' for the first apiversion, or just 'pods' for the v1 apiversion.
                # In other words, I can preemptively clean any APIVERSION of '/ + <string>' or any APIVERSION without a / entirely.
                label = 'APIVERSION'
                expression = {
                    if ( $_.APIVERSION -match '/' ) { ( $_.APIVERSION -split '/' )[0] }
                }
            },
            NAMESPACED, KIND, VERBS, CATEGORIES,
            @{
                label = 'DEFAULTAPIVERSION'
                expression = {
                    if ( [Kube]::MapDefaultApiVersions.ContainsKey($_.Name) ) { [Kube]::MapDefaultApiVersions.$($_.Name) }
                    else {
                        $thisResourceName = $_.NAME
                        if ( $apiResources | Group-Object NAME | Where { $_.NAME -eq $thisResourceName -and $_.Count -gt 1 }) {
                            $_.APIVERSION
                        }
                    }
                }
            }
        #>
    }

    static [string] Initialize_KubeApiAutocomplete([bool]$forceReloadAll) {
        If ( ! [Kube]::CurrentNamespace -or $forceReloadAll) {
            [Kube]::Checkpoint_CurrentNamespace()
            [Kube]::Set_KubeNamespaceEnum()
            [Kube]::UpdateKubeMappedContexts()
        }

        $resources = [Kube]::Import_APIResourceList()
        [Kube]::ArrayOfApiResources = $resources.NAME + ( $resources.SHORTNAMES | Where-Object {$_} | ForEach-Object { $_ -split ',' } ) | Sort-Object -Unique
        [Kube]::FullApiResources = $resources
# Does dynamickube do anything?        
        <#
        [StringBuilder]$dynamicClass = 'class DynamicKube { static [string]$CurrentNamespace' + [Environment]::NewLine
        $usedResources = @()
        Foreach ( $r in $resources ) {
            $rName = $r.Name
            
            If ( $rName -notin $usedResources ) {
                $dynamicClass.AppendLine("static [string[]] Get_$rName (){ return ((kubectl -n `$([Kube]::CurrentNamespace) get $rName -o name) | %{ `$_ -split '/' | select -last 1}) }")
            }
            $usedResources += $rName # check
        }
        $dynamicClass.AppendLine('}')
        #write-host $dynamicClass.ToString()
        return $dynamicClass
        #>
        return 'Start-Sleep -Milliseconds 1'
    }

    static [string[]] Get_Pods (){
        return (kubectl get pods -o name) -replace 'pod/'
    }
    static [string[]] Get_Namespaces (){
        return (kubectl get namespaces -o name) -replace 'namespace/'
    }
    static [string] Checkpoint_CurrentNamespace () {
        $currentNS = (kubectl config get-contexts | Select-String '^\*') -replace '.* ' # faster way?
        [Kube]::CurrentNamespace = $currentNS
        return $currentNS
    }
    static [void] Set_KubeNamespaceEnum() {
        $prefixesToInclude = [Kube]::SyncNamespacePrefixesToInts -join '|'

        $namespaces = if ( $prefixesToInclude ) {
            [Kube]::Get_Namespaces() | Where-Object { $_ -match "^$prefixesToInclude" }
        } else {
            [Kube]::Get_Namespaces()
        }
        #[Array]::Reverse($namespaces)
        #$count = $namespaces.count
        $count = 1
        [Kube]::MapIntsToNamespaces = @{}
        $namespaces.ForEach({
            [Kube]::MapIntsToNamespaces.$count = $_
            $count += 1
        })
        if ( $prefixesToInclude ) {
            [Kube]::Get_Namespaces() | Where-Object {$_ -notmatch "^$prefixesToInclude"} | ForEach-Object {
                [Kube]::MapIntsToNamespaces.$count = $_
                $count += 1
            }
        }
    }
    static [void] UpdateKubeMappedContexts() {
        try {
            $contexts = Import-PowerShellDataFile ([Kube]::ContextFile)#& { $o = [ordered]@{}; ($ht = Import-PowerShellDataFile $HOME\Documents\tenants\contexts.psd1) | Select -exp Keys | Sort | % { $o.Add($_,$ht[$_])}; $o }
        } catch {
            Write-Verbose "No contextFile map found. This is used by the `Get-KubeContext` function to shortcut access to different contexts. Checked [Kube]::contextFile for a PowerShellDataFile and found path: $([Kube]::contextFile)"
            $contexts = @{}
        }
        $modularContexts = if ( [Kube]::ModularContextFile -and (Test-Path ([Kube]::ModularContextFile)) ) {
            try {
                Import-PowerShellDataFile ([Kube]::ModularContextFile)
            } catch {
                @{}
            }
        } else { @{} }
        
        # If keys exist in both context files, give priority to the modular contexts.
        $contexts.Clone().GetEnumerator() | where Key -in $modularContexts.Keys | foreach {
            $contexts.Remove($_.Key)
        } 
        
        $sortedContexts = [SortedList]($contexts + $modularContexts)
        
        $orderedMappings = [ordered]@{}

        $sortedContexts.GetEnumerator() | ForEach-Object {
            $orderedMappings.Add($_.Key, $_.Value)
        }

        [Kube]::MappedContexts = $orderedMappings
    }
}
