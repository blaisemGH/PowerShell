class KubeNodeMetrics {
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
}