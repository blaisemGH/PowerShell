using namespace System.Collections.Generic
function Get-KubeNodesByPod {
    <#
        .SYNOPSIS
        Displays each pod in the specified namespaces(s) along with the pod's aggregate container metrics and node information.
        .DESCRIPTION
        Joins the kubernetes metrics api for containers to a list of nodes. The node metrics shown are the aggregate of all of the pods on the node,
        given by summing up each pod's individual container metrics as obtained from the kubernetes metric api.

        Note there are 3 view filters possible. PodOnly shows the nodes matched to pods. MetricsOnly shows the Node metrics from the pods. Combined gives both.
        .OUTPUTS
            Output object has the following properties:

            [string]$NodeName
            [string]$NodeType
            [string]$Namespace
            [string[]]$Pods
            [int]$PodCount
            [int]$MaxCpu
            [string]${Cpu%}
            [double]$CpuUsed
            [string]$MaxMemory
            [string]${Memory%}
            [double]$MemoryUsed
            [MemoryUnits]$MemoryUnits

            where MemoryUnits is any unit prefix from b for bytes to y for yotta (10^24).
                The binary or decimal form is accepted. A single letter defaults to decimal, e.g., g defaults to gb.
        .EXAMPLE
        Get-KubeNodesByPod
        .EXAMPLE
        gknp
        .EXAMPLE
        gknp -ViewFilter MetricsOnly
    #>
    param(
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
        [HashSet[string]]$Namespaces = (kubectl config view --minify -o json | ConvertFrom-Json).contexts.context.namespace ?? 'Default',
        [ValidateSet('PodsOnly', 'MetricsOnly', 'Combined')]
        [string]$ViewFilter = 'PodsOnly',
        [MemoryUnits]$OutputMemoryUnits = 'Gb'
    )

    [type]$viewClass = switch ($ViewFilter) {
        'MetricsOnly' {'KubeNodesByPodMetricsView'}
        'Combined' {'KubeNodesByPodCombinedView'}
        DEFAULT {'KubeNodesByPodDefaultView'}
    }

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
            'e' = {$_.status.capacity.cpu}
        }, @{
            'l' = 'MaxMemory'
            'e' = {[Math]::Round(($_.status.capacity.memory | Convert-MemoryUnits -ToUnits $OutputMemoryUnits | Select-Object -ExpandProperty Memory))}
        }
    
    $podYaml = $null
    Foreach ( $ns in $Namespaces ) {
        Get-KubeResource -Namespace $ns pods -o yaml -ov +podyaml > $null
    }
    $podConfigs = $podYaml | Select-Object @{
        l = 'NameFromYaml'
        e = {$_.metadata.name}
    }, @{
        l = 'NodeFromYaml'
        e = {$_.spec.nodeName}
    }, @{
        l = 'PodCpuRequest'
        e = {$_.spec.containers.resources.requests.cpu | Convert-KubeCpu | Measure-Object -Sum | Select-Object -ExpandProperty Sum}
    }, @{
        l = 'PodMemRequest'
        e = {
            $_.spec.containers.resources.requests.memory |
                Convert-MemoryUnits -ToUnits $OutputMemoryUnits |
                Measure-Object Memory -Sum |
                Select-Object -ExpandProperty Sum
        }
    }

    $podMetrics = Get-KubeMetrics -Namespaces $Namespaces -ViewFilter All | 
        Group-Object Namespace, PodName |
        Select-Object @{
            label = 'Namespace'
            expression = {$_.name -split ',\s*' | select -first 1 }
        }, @{
            label = 'PodName'
            expression = {$_.name -split ',\s*' | select -last 1 }
        }, @{
            label = 'Cpu'
            expression = {$_.Group.CPU | Convert-KubeCpu | Measure-Object -Sum | Select-Object -ExpandProperty Sum}
        }, @{
            label = 'Memory'
            expression = {$_.Group |
                Measure-Object MemoryGB -Sum |
                Select-Object -ExpandProperty Sum | 
                Convert-MemoryUnits -FromUnits Gb -ToUnits $OutputMemoryUnits
            }
        }

    $podInfo = Join-ObjectLinq $podConfigs $podMetrics NameFromYaml PodName | Where {$_} # Can have random null value here somehow
    $nodesByPod = Join-ObjectLinq $nodes $podInfo NodeName NodeFromYaml | Group-Object nodeName

    $nodesByPod | Foreach {
        $namespace = $_.Group.Namespace | Sort-Object -Unique
        $maxCores = $_.Group.MaxCores | Sort-Object -Unique
        $cores = $_.Group.Cpu | Measure-Object -Sum | Select-Object -ExpandProperty Sum
        $maxMemory = $_.Group.MaxMemory | Sort-Object -Unique
        $memory = $_.Group.Memory | Measure-Object Memory -Sum | Select-Object -ExpandProperty Sum
        $memoryUnits = $_.Group.Memory.Units | Sort-Object -Unique
        $nodeType = $_.Group.NodeType | Sort-Object -Unique
        
        @{
            NodeName = $_.Name
            NodeType = $nodeType
            Namespace = $namespace
            Pods = $_.Group.PodName #-join "`n" #', '
            PodCount = $_.Count
            MaxCpu = $maxCores
            CpuUsed = $cores
            'Cpu%' = "$(([Math]::Round($cores / $maxCores, 3) * 100).ToString('0.00'))%"
            MaxMemory = $maxMemory
            MemoryUsed = $memory
            'Memory%' = "$(([Math]::Round($memory / $maxMemory,3) * 100).ToString('0.00'))%"
            MemoryUnits = $memoryUnits
        } -as $viewClass
    }
}
