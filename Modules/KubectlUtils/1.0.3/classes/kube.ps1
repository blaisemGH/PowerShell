using namespace System.Collections.Generic
using namespace System.Collections.Specialized
using namespace System.Text

Class Kube {
    static [string[]]$ArrayOfApiResources
    static [string]$CurrentNamespace
    static [HashSet[String]]$SyncNamespacePrefixesToInts = @()
    static [hashtable]$MapIntsToNamespaces = @{}
    
    static [string] $relevantContainersFile = "$HOME/.pwsh/KubectlUtils/relevantContainers.psd1"
    static [HashSet[string]] $relevantContainers = ( & {
        try {
            return (Import-PowerShellDataFile ([Kube]::relevantContainersFile) -ErrorAction Stop).Values
        } catch {
            Write-Verbose "No relevant containers found. These are used in e.g., `Get-KubeMetrics` to filter a curated list of relevant containers. Checked [kube]::relevantContainersFile for a PowerShellDataFile and found path: $([Kube]::relevantContainersFile)"
            return [HashSet[string]]@($null)
        }
    })

    static [string] $contextFile = "$HOME/.pwsh/KubectlUtils/contexts.psd1"
    static [hashtable] $mapGCloudContexts = ( & {
        try {
            return Import-PowerShellDataFile ([Kube]::contextFile)#& { $o = [ordered]@{}; ($ht = Import-PowerShellDataFile $HOME\Documents\tenants\contexts.psd1) | Select -exp Keys | Sort | % { $o.Add($_,$ht[$_])}; $o }
        } catch {
            Write-Verbose "No contextFile map found. This is used by the `Get-KubeContext` function to shortcut access to different contexts. Checked [Kube]::contextFile for a PowerShellDataFile and found path: $([Kube]::contextFile)"
            return [HashSet[string]]@($null)
        }
    })

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
            kubectl api-resources -o wide |
                Select-String -Pattern 'NAME|get[^a-zA-Z0-9]' -CaseSensitive |
                Select-String -NotMatch 'metrics.k8s.io', 'backups\s*oracle.db.antho', 'events.k8s.io' |
                    ForEach {
                        $_ -replace 
                        '^ *' -replace 
                        '^(\S+)\s+(\S)(?<=.{50,})' , '$1  $2' -replace
                        ' {3,}' , ' ' -creplace
                        'VERBS.*' ,'VERBS'
                    } | 
                    ConvertFrom-Csv -Delimiter ' '
        )
    }

    static [string] Initialize_KubeApiAutocomplete([bool]$forceReloadAll) {
        If ( ! [Kube]::CurrentNamespace -or $forceReloadAll) {
            [Kube]::Checkpoint_CurrentNamespace()
            [Kube]::Set_KubeNamespaceEnum()
        }

        $resources = [Kube]::Import_APIResourceList()
        [Kube]::ArrayOfApiResources = $resources.NAME + ( $resources.SHORTNAMES | Where {$_} | ForEach { $_ -split ',' } )
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
        return 'Sleep -Milliseconds 1'
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
            [Kube]::Get_Namespaces() | Where { $_ -match "^$prefixesToInclude" }
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
            [Kube]::Get_Namespaces() | Where {$_ -notmatch "^$prefixesToInclude"} | ForEach {
                [Kube]::MapIntsToNamespaces.$count = $_
                $count += 1
            }
        }
    }
}
