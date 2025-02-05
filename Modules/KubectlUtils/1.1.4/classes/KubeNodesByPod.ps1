class KubeNodesByPod {
    [string]$NodeName
    [string]$NodeType
    [string]$Namespace
    [string[]]$Pods
    [int]$PodCount
    [int]$MaxCpu
    [double]$CpuUsed
    [string]${Cpu%}
    [double]$CpuReq
    [double]$CpuReqFraction
    [string]$MaxMemory
    [double]$MemoryUsed
    [string]${Memory%}
    [double]$MemReq
    [double]$MemReqFraction
    [MemoryUnits]$MemoryUnits
}

class KubeNodesByPodDefaultView : KubeNodesByPod {}

class KubeNodesByPodMetricsView : KubeNodesByPod {}

class KubeNodesByPodCombinedView : KubeNodesByPod {}

class KubeNodesByPodRequestsView : KubeNodesByPod {}