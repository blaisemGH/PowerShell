using namespace System.Management.Automation

function Update-ContextFileMap {
    param (
        [Parameter(Mandatory)]
        [string]$ProjectID,
        [Alias('key')]
        [string]$NewMapKey
    )
    
    $contextMap = Import-PowerShellDataFile ([Kube]::ContextFile)

    $kubeContext = kubectl config view -o json |
        ConvertFrom-Json |
        Select-Object -ExpandProperty Contexts |
        Where-Object name -match $ProjectID |
        Select-Object -ExpandProperty Name
    
    if ($contextMap.Values -contains $kubeContext ) {
        $confirm = Test-ReadHost -Query "Context map already contains a matching context. Would you like to replace it? [y/n]" -ValidationStrings 'y', 'n'
        if ( $confirm -eq 'y') {
            $oldKey = $contextMap.GetEnumerator() | Foreach { if ( $_.Value -eq $kubeContext ) { $_.Key }}
            $contextMap.Remove($oldKey)
        }
        else {
            $err = [ErrorRecord]::new('Voluntarily elected to chicken out', $null, 'InvalidResult', $null)
            $PSCmdlet.ThrowTerminatingError($err)
        }
    }

    $newKey = & {
        if ( $NewMapKey ) {
            $newMapKey
        } else {
            Read-Host "What string shortcut would you like to map to the new context $kubeContext?"
        }
    }

    if ( $newKey ) {
        $contextMap.Add( $newKey, $kubeContext )
    }
    else {
        [int]$lastPlaceholder = $contextMap.Keys | Where {$_ -match '^undecided-[0-9]+$' } | Sort-Object | Select-Object -last 1
        $newPlaceholder = 'undecided-{0:d2}' -f ($lastPlaceholder + 1)
        "Defaulting shortcut to $newPlaceholder"
        $contextMap.Add( $newPlaceholder, $kubeContext )
    }
    return $contextMap
}
    
    

function Export-ContextFileAsPSD1 {
    param(
        [Parameter(Mandatory,ValueFromPipeline)]
        [hashtable]$ContextMap
    )
    begin {
        $NL = [Environment]::NewLine

        [ValidateNotNullOrEmpty()]$pathContextFile = [Kube]::contextFile
        $contextParent = Split-Path $pathContextFile -Parent
        $contextLeaf = Split-Path $pathContextFile -Leaf
        [ValidateNotNullOrEmpty()]$pathBackupContextFile = Join-Path $contextParent ($contextLeaf -replace '^', 'bkp_')

        $newContent = '@{' + $NL
    }
    process {
        Foreach ( $key in $ContextMap.Keys ) {
            $newContent += "`t'" + $key + "' = '" + $contextMap.$key + "'" + $NL
        }
    }
    end {
        $newContent += '}'
        try {
            Copy-Item -Path $pathContextFile -Destination $pathBackupContextFile -Force -ErrorAction Stop
            $newContent | Set-Content $pathContextFile -Force -ErrorAction Stop
        }
        catch {
            $pathFailedContextFile = Join-Path $contextParent ($contextLeaf -replace '^', 'failed_')
            $newContent | Set-Content $pathFailedContextFile -Force

            Write-Error ( $_ | Out-String )

            $err = [ErrorRecord]::new(
                "Failed to update context file at $pathContextFile.
                Created a backup file at $pathBackupContextFile
                Created a file of the failed update contents at $pathFailedContextFile",
                $null, 'WriteError', $null
            )
            $PSCmdlet.ThrowTerminatingError($err)
        }    
        if ($?) {
            Remove-Item $pathBackupContextFile -Force
            [Kube]::UpdateKubeMappedContexts()
        }
    }
}