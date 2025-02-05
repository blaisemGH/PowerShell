class KubeNodesByPod {
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
}

class KubeNodesByPodDefaultView : KubeNodesByPod {}

class KubeNodesByPodMetricsView : KubeNodesByPod {}

class KubeNodesByPodCombinedView : KubeNodesByPod {}