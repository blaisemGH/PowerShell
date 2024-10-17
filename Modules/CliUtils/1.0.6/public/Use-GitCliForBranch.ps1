<#
    .SYNOPSIS
        A function I am still working on that is a wraper for the git cli tool. Specifically it is for streamlining the handling of branches: creation, committing, pushing, and deleting branches.
        
        I mostly missed having autocomplete and didn't like remembering some arbitrary hard-coded values. This function is a WIP to possibly simplify this.
        Line 65 contains the current usage setup.
#>

Function Use-GitCliForBranch {
    [CmdletBinding(DefaultParameterSetName='list')]
    Param(
        [Parameter(ValueFromRemainingArguments)]
        [string[]]$ExtraArgs,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='add')]
        [Alias('add')]
        [switch]$AddItems,

        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='pull')]
        [GitRemoteBranchCompletions()]
        [Alias('pb')]
        [string]$PullBranch,

        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='create')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='delete')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='checkout')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='rename')]
        [Parameter(ValueFromPipeline, Position = 0, ParameterSetName='push')]
        [GitLocalBranchCompletions()]
        [Alias('b')]
        [string]$BranchName,

        [Parameter(Mandatory,ParameterSetName='create')]
        [Alias('n')]
        [switch]$NewBranch,

        [Parameter(Mandatory,ParameterSetName='delete')]
        [Alias('d')]
        [switch]$DeleteBranch,

        [Parameter(ParameterSetName='checkout')]
        [switch]$CheckoutBranch,

        [Parameter(ParameterSetName='list')]
        [Alias('ls')]
        [switch]$List,

        [Parameter(Mandatory, ParameterSetName='push')]
        [Alias('p')]
        [switch]$Push,
        [Parameter(ParameterSetName='push')]
        [switch]$ForcePush,

        [Parameter(Mandatory, ParameterSetName='commit')]
        [Alias('c')]
        [string]$CommitMessage,

        [Parameter(Mandatory, ParameterSetName='rename')]
        [switch]$Rename,

        [Parameter(Mandatory, ParameterSetName='rename')]
        [string]$RenamedBranchName,

        [Parameter(Mandatory, ParameterSetName='squash')]
        #[ValidatePattern('^([a-z0-9]{7}|[a-z0-9]{40})$')]
        [GitLocalCommitsCompletions()]
        [string]$SquashToCommitId,

        [Parameter(Mandatory, ParameterSetName='squash')]
        [string]$SquashCommitMessage,

        [Parameter(ParameterSetName='merge')]
        [GitLocalBranchCompletions()]
        [Alias('merge')]
        [string]$MergeBranch,
        [Parameter(ParameterSetName='merge')]
        [switch]$MergeAbort,
        [Parameter(ParameterSetName='merge')]
        [switch]$MergeContinue,

        [Parameter(ParameterSetName='rebase')]
        [GitLocalBranchCompletions()]
        [string]$RebaseBranch,
        [Parameter(ParameterSetName='rebase')]
        [switch]$RebaseAbort,
        [Parameter(ParameterSetName='rebase')]
        [switch]$RebaseContinue,

        [Parameter(Mandatory, ParameterSetName='switch')]
        [GitRemoteBranchCompletions()]
        [string]$SwitchBranch,

        [Parameter(Mandatory, ParameterSetName='resetHard')]
        [GitLocalCommitsCompletions()]
        [string]$ResetHard,
        [Parameter(Mandatory, ParameterSetName='resetSoft')]
        [GitLocalCommitsCompletions()]
        [switch]$ResetSoft,

        [Parameter(Mandatory, ParameterSetName='chmodX')]
        [GitNewShellFilesCompletions()]
        [string]$GrantChmodToFile,
        [Parameter(ParameterSetName='chmodX')]
        [ValidateScript({
            $permissions = $_.Trim('ugo')
            if ( $permissions -as [chmod] ) {
                return $true
            } elseif ( $permissions.Length -in 1,2,3 -and ($permissions.ToCharArray() -join ',') -as [chmod] ) {
                return $true 
            }
        })]
        [TransformToChmodGrant()]
        [string]$ChmodPermission = 'o+x'

    )
    DynamicParam {
        if ( !$NewBranch, !$DeleteBranch, !$List, !$Push, !$CommitMessage ) {
            $parameterAttribute = [System.Management.Automation.ParameterAttribute]@{
                ParameterSetName = 'checkout'
                Mandatory = $true
            }
            $attributeCollection = [System.Collections.ObjectModel.Collection[System.Attribute]]@($parameterAttribute)
            $dynParam1 = [System.Management.Automation.RuntimeDefinedParameter]::new('dynCheckout', [switch], $attributeCollection)
            #$paramDictionary = [System.Management.Automation.RuntimeDefinedParameterDictionary]::new().Add('dynCheckout', $dynParam1)
            #return $paramDictionary
        }
    }
    begin {
        $currentBranch = if ($PSCmdlet.ParameterSetName -eq 'Push' -and !$BranchName) {
            git branch --show-current
        }
        else {
            $BranchName
        }
     }
    process {

        $useForcePush = if ( $ForcePush ) { '--force' }

        $sbAddArg = {
            if ( git branch --show-current 2>$null ) {
                #Get-ChildItem -Recurse -File -Filter *.sh | ForEach-Object { git update-index --chmod=+x $_.FullName }
            }
            'add *'
        }

        $sbGitChmodPermission = {
            '--chmod=+' + ($ChmodPermission -split '\+' | Select-Object -Last 1)
        }

        $sbMergeArg = {
            if ( $MergeAbort ) {
                'merge --abort'
            } elseif ( $MergeContinue ) {
                $conflictedFiles = git diff --name-only --diff-filter=U --relative
                foreach ($file in $conflictedFiles) {
                    "add $file"
                }
                'merge --continue'
            } elseif ( $MergeBranch ) {
                "merge $MergeBranch"
            }
        }

        $sbRebaseArg = {
            if ( $RebaseAbort ) {
                'rebase --abort'
            } elseif ( $RebaseContinue ) {
                $conflictedFiles = git diff --name-only --diff-filter=U --relative
                foreach ($file in $conflictedFiles) {
                    "add $file"
                }
                'rebase --continue'
            } elseif ( $RebaseBranch ) {
                "rebase $RebaseBranch"
            }
        }

        if ( $ExtraArgs ) {
            [string[]]$gitCommands = (git -h | Select-String '(?<=^\s{3})(\S+)').Matches.Value
            if ( $BranchName -in $gitCommands ) {
                $gitArgs = $BranchName + $ExtraArgs
                Write-Verbose "Running $($gitArgs -join ' ')"
                git @gitArgs
                break
            }
        }

        [string[]]$commands = Switch ($PSCmdlet.ParameterSetName) {
            add       { & $sbAddArg }
            chmodX    { "update-index $(& $sbGitChmodPermission) $GrantChmodToFile"}
            create    { "checkout -b $BranchName"                   }
            delete    { "branch -D $BranchName"                     }
            checkout  { "checkout $BranchName"                      }
            list      { 'branch'                                    }
            commit    { 'commit -a -m "{0}"' -f $CommitMessage      }
            merge     { & $sbMergeArg                               }
            rebase    { & $sbRebaseArg                              }
            rename    { "branch -m $BranchName $RenamedBranchName"  }
            resetHard { "reset $ResetHard --hard" }
            resetSoft { "reset $ResetSoft --soft" }
            push      { "push --set-upstream origin $currentBranch $useForcePush" }
            squash    {
                "reset --soft $SquashToCommitId"
                'commit -a -m "{0}"' -f $SquashCommitMessage
            }
            'switch'  { "switch $SwitchBranch"                      }
        }

        foreach ($cmd in $commands) {
            Write-Host "Executing: git $cmd"
            $cmdArgs = if ( $cmd -match '\s' ) {
                $cmd.Trim() -split '(?s)(?<!".*)\s+'
            } else {
                $cmd
            }
            $trimCmdArgs = $cmdArgs.Trim().Trim('''"')

            git @trimCmdArgs
        }
    }
}

#git diff (need to create a hashtable of commits to reference by index with first line of commit message as description on tab completion)
       <#
        $squashLogic = {
            param($BranchName, $SquashToCommitId ) #$LimitIterations)
            # git config --list | sls user.name | % {$_ -split '=' | select -last 1}
            # Can go down the commits using the below loop (update pretty format with author name) until a different author and use that.
            <#if ( $LimitIterations -eq '0' ) {
                $confirm = Read-Host 'Will squash everything since the previous '
            } else {
                [int]$count = $LimitIterations
            }
            git checkout $BranchName
            $logEntries = foreach ( $logEntry in (git log --pretty=format:'%H | %D') ) {
                if ( $count -lt 0 ) {
                    break
                }
                $hash, $refNames = $logEntry -split '\s*\|\s*', 2
                if ( $refNames.Trim() -notmatch '^HEAD' -and !$startIndexingAfterHead ) {
                    continue
                }
                elseif ( $refNames.Trim() -match '^HEAD' ) {
                    $startIndexingAfterHead = $true
                }
                $parentBranch = ($refNames -split ',')[-1]
                [PSCustomObject]@{
                    hash = $hash
                    parentBranch = $parentBranch
                }
                
                $count -= 1

                if ( $parentBranch -and $refNames.Trim() -notmatch '^HEAD' -and $LimitIterations -eq 0) {
                    break
                }
            }
            $lastHash = $logEntries[-1].hash

            $tempBranchName = $BranchName + [guid]::NewGuid().Guid.Substring(0,8)
            try {
                git branch $tempBranchName
                git reset --hard $SquashToCommitId
                git merge -n --squash $tempBranchName
            } finally {
                git checkout $BranchName
                git branch -D $tempBranchName
            }
        }#>
