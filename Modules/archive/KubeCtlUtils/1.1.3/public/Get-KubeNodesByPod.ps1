function Get-KubeNodesByPod {
    <#
        .SYNOPSIS
        Displays each pod in the current namespace according to which node it currently resides on
        .EXAMPLE
        Get-KubeNodesByPod
        .EXAMPLE
        gknp
    #>
    $nodes = kubectl get nodes -o json | 
        ConvertFrom-Json |
        Select-Object -ExpandProperty Items |
        Select-Object @{
            'l' = 'nodeName'
            'e' = { if ($_.metadata.name) { $_.metadata.name } else { '<none>' } }
        }, @{
            'l' = 'nodeType'
            'e' = {$_.metadata.labels.'node.kubernetes.io/instance-type'}
        }, @{
            'l' = 'cores'
            'e' = {$_.status.capacity.cpu}
        }, @{
            'l' = 'memory'
            'e' = {($_.status.capacity.memory  -replace 'Ki' )/ 1024 / 1024 }
        }
    
    Get-KubeResource pods -o wide -ov pods > $null
    $out = Join-ObjectLinq $nodes $pods nodeName node |
        select name, nodename, nodetype, cores, memory |
        group nodeName
    
    $out | Foreach {
        [KubeNodesByPod]@{
            PodCount = $_.Count
            NodeType = ($_.Name -replace '^.+nap-' -replace '(?<=-[0-9]{0,4})(-.+)$').Trim('-') -replace '(?<=[a-z])(-[0-9])?$', ('-' + $_.group[0].cores)
            CoresAndMem = ('{0,2}' -f ($_.group[0].cores)) + ' / ' + [math]::round($_.group[0].memory)
            Pods = $_.group.name -join "`n" #', '
            NodeName = $_.Name
        }
    }
}
