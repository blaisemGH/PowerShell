class KubeCommandTransform : ArgumentTransformationAttribute {
    static $AllowedCommands = (
        (
            (kubectl --help) -join
            [Environment]::NewLine -replace
            '(?s).*(Find more information.*Usage:).*', '$1'
        ) -split
            [Environment]::NewLine | Foreach {
                $_ -split '  ' | Select-Object -Index 1
            }
    )
    [object] Transform([EngineIntrinsics]$engineIntrinsics, [object] $inputData) {
        $transform = switch -regex ($inputData) {
            ^a$ { apply }
            ^d$ { describe; break }
            ^e$ { edit }
            ^g$ { get }
            ^l$ { logs }
            ^p$ { port-forward }
            ^r$ { rollout }
            ^s$ { scale }
            DEFAULT { $_ }
        }

        [string[]]$command = $transform | Where $AllowedCommands -match $transform
        
        if ($command.Count -gt 1) {
            throw "Unambiguous command! Did you mean 1 of $($command)"
        }
        elseif ($command.Count -eq 0 ) {
            throw "Could not match $inputData to a valid command. Must be one of $([KubeCommandTransform]::AllowedCommands)"
        }
        
        return [string]$command
    }
}