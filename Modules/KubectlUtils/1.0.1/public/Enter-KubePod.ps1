Function Enter-KubePod {
    Param(
        [Parameter(Mandatory, Position=0)]
        [alias('p')]
        [string]$PodName,
        [Parameter(ValueFromRemainingArguments)]
        [alias('r')]
        [string]$RunCmd = 'bash',
        [alias('n')]
        [switch]$NotInteractive,
        [alias('c')]
        [switch]$Container
    )
    $date = Get-Date
    $target = if ( $Container ) { "$PodName -c $Container" } else { $PodName }
    $it = if ( $NotInteractive -or $RunCmd -notin 'bash','sh') { $null } else { '-it' }
    kubectl ( "exec $it $target -- $RunCmd" -split ' +')
    if ( !$? -and $RunCmd -eq 'bash' -and ((Get-Date) - $date).TotalSeconds -lt 2 ) {
        kubectl ("exec $it $target -- sh" -split ' +')
    }
}
