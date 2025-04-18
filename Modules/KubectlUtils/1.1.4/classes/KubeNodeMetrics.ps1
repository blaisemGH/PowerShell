class KubeNodeMetrics {
    [string]$Node
    [string]$NodeType
    [string[]]$Namespaces
    [int]$CpuMax
    [double]$CpuUsed
    [string]${Cpu%}
    [double]$CpuReq
    [string]${CpuReq%}
    [double]$MemMax
    [double]$MemUsed
    [string]${Mem%}
    [double]$MemReq
    [string]${MemReq%}
    [MemoryUnits]$MemUnits
}

class KubeNodeMetricsActualView : KubeNodeMetrics {}

class KubeNodeMetricsRequestView : KubeNodeMetrics {}

class KubeNodeMetricsCombinedView : KubeNodeMetrics {}