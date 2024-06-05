Function Measure-DiskIO {
    Param(
        [Parameter(Mandatory)]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                [string[]]@((kubectl get pods -o name) -replace '^pod/') | Where-Object {
                    $_ -like "$wordToComplete*"
                }
            }
        )]
        [string]$pod
    )
    (kubectl exec $pod -- cat /proc/diskstats) -replace '^\s+' -replace '\s+',',' | ConvertFrom-Csv -Header 'c1','c2','disk','reads','rmerge','rsector','rtime','writes','wmerge','wsector','wtime','nowOps','timeOps','allOps','discards','dmerge','dsector', 'dtime','flushOps','ftime' | ft * -AutoSize -wrap
}
