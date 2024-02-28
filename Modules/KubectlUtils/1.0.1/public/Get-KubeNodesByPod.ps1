Function Get-KubeNodesByPod {
    $nodes = kubectl get nodes -o json | 
        ConvertFrom-Json |
        select -exp Items |
        select @{
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
        [ViewNodesByPod]@{
            PodCount = $_.Count
            nodeType = ($_.Name -replace '^.+nap-' -replace '(?<=-[0-9]{0,4})(-.+)$').Trim('-')
            CoresAndMem = ('{0,2}' -f ($_.group[0].cores)) + ' / ' + [math]::round($_.group[0].memory)
            pods = $_.group.name -join [Environment]::NewLine #', '
            NodeName = $_.Name
        }
    }
}
