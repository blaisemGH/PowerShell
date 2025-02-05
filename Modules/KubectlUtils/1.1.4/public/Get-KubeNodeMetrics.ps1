using namespace System.Collections.Generic
function Get-KubeNodeMetrics {
    <#
        .SYNOPSIS
        Displays node metrics from kubectl top node by namespace
        .DESCRIPTION
        This parses all pods in the specified namespaces and matches each to a node from kubectl top node. For a list of pods on each node, use gknp.
        .OUTPUTS
            Output object has the following properties:

            [string]$Namespaces
            [string]$Node
            [string]$NodeType
            [int]$CpuMax
            [double]$CpuUsed
            [string]${Cpu%}
            [double]$MemMax
            [double]$MemUsed
            [string]${Mem%}
            [MemoryUnits]$MemUnits

            where MemoryUnits is any unit prefix from b for bytes to y for yotta (10^24).
                The binary or decimal form is accepted. A single letter defaults to decimal, e.g., g defaults to gb.
        .EXAMPLE
        Get-KubeNodeMetrics
        .EXAMPLE
        gknm -Namespaces 'a', 'b'
    #>
    param(
        # Specify comma-separated namespaces to evaluate. -A or --all-namespaces are also valid. A given node will appear in the output once for each namespace.
        [Parameter(ValueFromRemainingArguments)]
        [ArgumentCompleter(
            {
                # Enables tab completion for comma-delimited arguments to param -Namespaces
                Param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                # The current element being tab-completed is the last command element in the ast.
                $lastElement = $commandAst.CommandElements[-1]
                # Depending on the context, the current value may be in .Value or .Elements.Value (Can't remember my testing here tbh)
                $paramTokens = $lastElement.Value + $LastElement.Elements.Value | Where-Object {$_}
                # If somehow multiple values are returned, then presumably the last one is the one currently being tab completed.
                $lastTokenToComplete = $paramTokens | Select-Object -Last 1
                # Previously used tokens are in NestedAst.Value
                $alreadyUsedTokens = $paramTokens + $LastElement.NestedAst.Value | Where-Object {$_}

                [Kube]::Get_Namespaces() + "'--all-namespaces'" + "'-A'" | Where-Object {
                    $_ -like "$lastTokenToComplete*" -and
                    $_ -notin $alreadyUsedTokens
                }
            }
        )]
        [HashSet[string]]$Namespaces = (kubectl config view --minify -o json | ConvertFrom-Json).contexts.context.namespace,
        [MemoryUnits]$OutputMemoryUnits = 'Gb'
    )

    $nodes = kubectl get nodes -o json | 
        ConvertFrom-Json |
        Select-Object -ExpandProperty Items |
        Select-Object @{
            'l' = 'NodeName'
            'e' = { if ($_.metadata.name) { $_.metadata.name } else { '<none>' } }
        }, @{
            'l' = 'NodeType'
            'e' = {$_.metadata.labels.'node.kubernetes.io/instance-type'}
        }, @{
            'l' = 'MaxCores'
            'e' = {$_.status.capacity.cpu} # Already comes as pure int
        }, @{
            'l' = 'MaxMemory'
            'e' = {[Math]::Round(($_.status.capacity.memory | Convert-MemoryUnits -ToUnits $OutputMemoryUnits | Select-Object -ExpandProperty Memory))}
        }

    $podYaml = $null
    foreach ($ns in $Namespaces) {
        Get-KubeResource -Namespace $ns pods -o yaml -ov +podYaml > $null
    }

    $nodesByNamespaces = $podYaml | Select @{
        label = 'Namespace'
        expression = { $_.metadata.namespace }
    }, @{
        label = 'Node'
        expression = { $_.spec.nodeName }
    } |
        Group-Object Namespace, Node | foreach {
            [pscustomobject]@{
                Namespace = $_.Group.Namespace
                Node = $_.Group.Node
            }
        }

    $nodesWithNamespaces = Join-ObjectLinq $nodes $nodesByNamespaces nodeName Node |
        Select-Object NodeName, NodeType, Namespace, MaxCores, MaxMemory
    
    $nodeMetrics = kubectl top node --show-capacity | ConvertFrom-StringTable

    Join-ObjectLinq $nodesWithNamespaces $nodeMetrics NodeName Name | Where {$_} | Foreach {
        $memory = $_.'MEMORY(bytes)' | Convert-MemoryUnits -ToUnits $outputMemoryUnits

        [KubeNodeMetrics]@{
            Namespaces = $_.Namespace
            Node = $_.Name
            NodeType = $_.nodeType
            CpuMax = $_.MaxCores
            CpuUsed = $_.'CPU(cores)' | Convert-KubeCpu
            'Cpu%' = $_.'CPU%'
            MemMax = $_.MaxMemory
            MemUsed = $memory.Memory
            'Mem%' = $_.'MEMORY%'
            MemUnits = $memory.Units
        }
    } | Sort-Object Namespaces
    # Sample output::
#Count         : 2
#Group         : {@{NAME=oracle-1915-monitor-74946847d8-n2vjd; nodeName=gke-gke-rct-t3jq-5xv-nap-n2-highmem-4-27d30feb-nfsw; nodeType=n2-highmem-48;
#                cores=48; memory=377.8879737854}, @{NAME=oracle-1915-sts-0; nodeName=gke-gke-rct-t3jq-5xv-nap-n2-highmem-4-27d30feb-nfsw;
#                nodeType=n2-highmem-48; cores=48; memory=377.8879737854}}
#Name          : gke-gke-rct-t3jq-5xv-nap-n2-highmem-4-27d30feb-nfsw
#Values        : {gke-gke-rct-t3jq-5xv-nap-n2-highmem-4-27d30feb-nfsw}
#CPU%          : 0%
#CPU(cores)    : 231m
#MEMORY%       : 34%
#MEMORY(bytes) : 135333Mi

}
