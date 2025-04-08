using namespace System.Collections
using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Text

Class Kube {
    static [string]$KubeLocalCache = "$HOME/.pwsh/KubectlUtils"
    static [string[]]$ArrayOfApiResources
    static [pscustomobject[]]$FullApiResources
    static [string]$CurrentNamespace
    static [string]$CurrentCluster
    static [hashtable]$Namespaces = @{}
    static [HashSet[String]]$SyncNamespacePrefixesToInts = @()
    static [hashtable]$MapIntsToNamespaces = @{}
    static [bool]$IsConfigForked
    static [scriptblock]$AddContext = {
        param($ContextName)
        kubectl config use-context $contextName
    }
    static [hashtable]$MapDefaultApiVersions = @{
        pods = 'v1'
        nodes = 'v1'
        events = 'v1'
    }
    
    static [string] $relevantContainersFile = [Kube]::KubeLocalCache + '/relevantContainers.psd1'
    static [HashSet[string]] $relevantContainers = ( & {
        try {
            return (Import-PowerShellDataFile ([Kube]::relevantContainersFile) -ErrorAction Stop).Values
        } catch {
            Write-Verbose "No relevant containers found. These are used in e.g., `Get-KubeMetrics` to filter a curated list of relevant containers. Checked [kube]::relevantContainersFile for a PowerShellDataFile and found path: $([Kube]::relevantContainersFile)"
            return [HashSet[string]]@($null)
        }
    })

    static [string] $ContextFile = [Kube]::KubeLocalCache + '/contexts.psd1'
    static [string] $ModularContextFile = ""
    static [OrderedDictionary] $MappedContexts

    static [string[]] Get_APIResourceList() {
        If ( [Kube]::ArrayOfApiResources ) {
            return [Kube]::ArrayOfApiResources
        }
        Else {
			[Kube]::Initialize_KubeApiAutocomplete($false)
            return [Kube]::ArrayOfApiResources
        }
    }
    static [scriptblock] GetFuncForAPIResourceList() {
        return {
            param([hashtable]$MapDefaultApiVersions)

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
                        expression = { if ( $_.Name -and $MapDefaultApiVersions.ContainsKey($_.Name) ) { $MapDefaultApiVersions.$($_.Name) } }
                    }
                }
        }
    }

    static [void] Initialize_KubeApiAutocomplete([bool]$forceReloadAll) {
        If ( ! [Kube]::CurrentNamespace -or $forceReloadAll) {
            [Kube]::Checkpoint_CurrentNamespace()
            #[Kube]::Set_KubeNamespaceEnum()
            [Kube]::UpdateKubeMappedContexts()
        }
        <#
        $sbToImportKubeResources = [Kube]::GetFuncForAPIResourceList()
        $asyncImportApiResources = Start-ThreadJob -ScriptBlock $sbToImportKubeResources -ArgumentList ([Kube]::MapDefaultApiVersions)
        
        Register-ObjectEvent -InputObject $asyncImportApiResources -EventName StateChanged -Action {
            Unregister-Event $EventSubscriber.SourceIdentifier
            $resources = Receive-Job -Id $EventSubscriber.SourceObject.Id -Keep
            [Kube]::ArrayOfApiResources = $resources.NAME + ( $resources.SHORTNAMES | Where-Object {$_} | ForEach-Object { $_ -split ',' } ) | Sort-Object -Unique
            [Kube]::FullApiResources = $resources
            Remove-Job -Id $EventSubscriber.SourceObject.Id
        }#>
    }

    static [string[]] Get_Pods (){
        return (kubectl get pods -o name) -replace 'pod/'
    }
    static [string[]] Get_Namespaces (){
        $contextNamespaces = [Kube]::Namespaces.$([Kube]::CurrentNamespace)
        if ( !$contextNamespaces ) {
            [Kube]::Namespaces.$([Kube]::CurrentNamespace) = (kubectl get namespaces -o name) -replace 'namespace/'
        }
        return [Kube]::Namespaces.$([Kube]::CurrentNamespace)
    }
    static [string] Checkpoint_CurrentNamespace () {

        $currentNS = if ( Get-Module ConfigFileUtils ) {
            $kubeConfigFile = if ( $env:KUBECONFIG ) { $env:KUBECONFIG } else { "~/.kube/config" }
            $config = Get-Content $kubeConfigFile -Raw | ConvertFrom-Yaml
            $currentContext = $config.'current-context'
            $config.Contexts.Where({ $_.context.cluster -eq $currentContext} ).context.namespace
        } else {
            $currentNS = (kubectl config get-contexts | Select-String '^\*') -replace '.* '
        }
        
        [Kube]::CurrentNamespace = $currentNS
        return $currentNS
    }
    static [void] Set_KubeNamespaceEnum() {
        $prefixesToInclude = [Kube]::SyncNamespacePrefixesToInts -join '|'

        $contextNamespaces = if ( $prefixesToInclude ) {
            [Kube]::Get_Namespaces() | Where-Object { $_ -match "^$prefixesToInclude" }
        } else {
            [Kube]::Get_Namespaces()
        }
        #[Array]::Reverse($namespaces)
        #$count = $namespaces.count
        $count = 1
        [Kube]::MapIntsToNamespaces = @{}
        $contextNamespaces.ForEach({
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
            $contexts = Import-PowerShellDataFile ([Kube]::ContextFile) -SkipLimitCheck #& { $o = [ordered]@{}; ($ht = Import-PowerShellDataFile $HOME\Documents\tenants\contexts.psd1) | Select -exp Keys | Sort | % { $o.Add($_,$ht[$_])}; $o }
        } catch {
            Write-Verbose "No contextFile map found. This is used by the `Get-KubeContext` function to shortcut access to different contexts. Checked [Kube]::contextFile for a PowerShellDataFile and found path: $([Kube]::contextFile)"
            $contexts = @{}
        }
        $modularContexts = if ( [Kube]::ModularContextFile -and (Test-Path ([Kube]::ModularContextFile)) ) {
            try {
                Import-PowerShellDataFile ([Kube]::ModularContextFile) -SkipLimitCheck
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
