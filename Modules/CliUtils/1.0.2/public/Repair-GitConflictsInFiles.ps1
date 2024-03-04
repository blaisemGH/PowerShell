function Repair-GitConflictsInFiles {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(1,2)]
        [int]$CommitToKeep,

        [Parameter(Mandatory,ValueFromPipelineByPropertyName,ParameterSetName='SingleFile')]
        [Alias('PSPath', 'LP')]
        [string]$FileInConflict,

        [Parameter(Mandatory,ParameterSetName='AllConflicts')]
        [switch]$ResolveAllConflicts
    )
    begin {
        if ($PSCmdlet.ParameterSetName -eq 'AllConflicts') {
            [string[]]$filesToEdit = git diff --check | foreach { $_ -split ':' | select -First 1 } | Sort-Object -Unique
            [void]($splatEditParameters = $PSBoundParameters).Remove('ResolveAllConflicts')
        }
        else {
            [void]($splatEditParameters = $PSBoundParameters).Remove('FileInConflict')
        }
    }
    process {
        if (!$filesToEdit) {
            [string[]]$filesToEdit = $FileInConflict
        }

        if ( $filesToEdit ) {
            try {
                $filesToEdit | Edit-GitConflictsInFile @splatEditParameters
            } catch { 
                $err = New-ErrorRecord "Failed to edit file conflicted in git ($($conflictedFile)) for commit order $($CommitToKeep). Exception message: $($_)"
                $PSCmdlet.ThrowTerminatingError($err)
            }
        }
    }
}

function Edit-GitConflictsInFile {
    param(
        [Parameter(Mandatory)]
        [ValidateSet(1,2)]
        [int]$CommitToKeep,
        
        [Parameter(Mandatory, ValueFromPipelineByPropertyName, ValueFromPipeline)]
        [Alias('PSPath', 'LP')]
        [string[]]$FileInConflict
    )
    begin {
        $removeLinesWithPattern = '^(?:<<<<<<< HEAD|=======|>>>>>>>.*)$'
        
        [ValidateNotNullOrEmpty()]
        $markBeginRemoveCommitLines = switch ($CommitToKeep) {
            1 { '^=======' }
            2 { '^<<<<<<< HEAD' }
        }

        [ValidateNotNullOrEmpty()]
        $markEndRemoveCommitLines = switch ($CommitToKeep) {
            1 { '^>>>>>>> ' }
            2 { '^======='  }
        }
    }
    process {
        
        foreach ($conflictedFile in $FileInConflict) {
            Write-Verbose "Processing file: $($conflictedFile)"

            $flagExcludeLines = $false
            (Get-Content $conflictedFile | foreach {
                if ( $_ -match $markBeginRemoveCommitLines ) {
                    $flagExcludeLines = $true
                }
                elseif ($_ -match $markEndRemoveCommitLines ) {
                    $flagExcludeLines = $false
                }

                if ( !$flagExcludeLines -and $_ -notmatch $removeLinesWithPattern) {
                    Write-Output $_
                }
            }) | Set-Content $conflictedFile
            
            git add $conflictedFile
        }

    }
}