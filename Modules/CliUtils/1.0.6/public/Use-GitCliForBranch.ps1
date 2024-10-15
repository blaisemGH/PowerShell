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

        [Parameter(Mandatory, ParameterSetName='commit')]
        [Alias('c')]
        [string]$CommitMessage,

        [Parameter(Mandatory, ParameterSetName='rename')]
        [switch]$Rename,

        [Parameter(Mandatory, ParameterSetName='rename')]
        [string]$RenamedBranchName,

        [Parameter(Mandatory, ParameterSetName='squash')]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                #%B for commit message
                git log --pretty=format:'%H | %an | %ad | %s | %D' --date=iso | Select-Object -First 30 | ForEach-Object {
                    $parts = $_ -split ' \| '
                    $id = $parts[0]
                    $author = ($parts[1] -split ' ')[-1]
                    $date = Get-Date $parts[2] -format 'yyyy-MM-dd HH:mm:ss'
                    $subject = $parts[3]
                    $tags = if ( $parts[4] ) { $parts[4] }
                    $tooltip = "$author | $date | $subject"
                    
                    [System.Management.Automation.CompletionResult]::new(
                        $id,
                        "$id | $tags",
                        [System.Management.Automation.CompletionResultType]::Text,
                        $tooltip
                    )
                } | Where-Object { $_.CompletionText -like "$wordToComplete*" }
            }
        )]
        #[ValidatePattern('^([a-z0-9]{7}|[a-z0-9]{40})$')]
        [string]$SquashToCommitId,

        [Parameter(Mandatory, ParameterSetName='squash')]
        [string]$SquashCommitMessage,

        [Parameter(ParameterSetName='merge')]
        [GitLocalBranchCompletions()]
        [string]$MergeBranch,
        [Parameter(ParameterSetName='merge')]
        [switch]$MergeAbort,
        [Parameter(ParameterSetName='merge')]
        [switch]$MergeContinue,

        [Parameter(Mandatory, ParameterSetName='rebase')]
        [GitLocalBranchCompletions()]
        [string]$RebaseBranch,
        [Parameter(ParameterSetName='rebase')]
        [switch]$RebaseAbort,
        [Parameter(ParameterSetName='rebase')]
        [switch]$RebaseContinue,

        [Parameter(Mandatory, ParameterSetName='switch')]
        [GitRemoteBranchCompletions()]
        [string]$SwitchBranch,

        [Parameter(Mandatory, ParameterSetName='switchHard')]
        [Parameter(Mandatory, ParameterSetName='switchSoft')]
        [GitRemoteBranchAndLocalCommitCompletions()]
        [string]$Reset,
        [Parameter(Mandatory, ParameterSetName='switchHard')]
        [switch]$Hard,
        [Parameter(Mandatory, ParameterSetName='switchSoft')]
        [switch]$Soft
        
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
    }
    process {

        $sbAddArg = {
            if ( git branch --show-current 2>$null ) {
                Get-ChildItem -Recurse -File -Filter *.sh | ForEach-Object { git update-index --chmod=+x $_.FullName }
            }
            'add *'
        }

        $sbMergeArg = {
            if ( $MergeAbort ) {
                'merge --abort'
            } elseif ( $MergeContinue ) {
                'merge --continue'
            } elseif ( $MergeBranch ) {
                "merge $MergeBranch"
            }
        }

        $sbRebaseArg = {
            if ( $RebaseAbort ) {
                'rebase --abort'
            } elseif ( $RebaseContinue ) {
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
            create    { "checkout -b $BranchName"                   }
            delete    { "branch -D $BranchName"                     }
            checkout  { "checkout $BranchName"                      }
            list      { 'branch'                                    }
            commit    { 'git commit -a -m "{0}"' -f $CommitMessage    }
            merge     { & $sbMergeArg                                 }
            rebase    { & $sbRebaseArg                                }
            rename    { "branch -m $BranchName $RenamedBranchName"  }
            push      { "push --set-upstream origin $currentBranch" }
            squash    { "reset --soft $SquashToCommitId", 'git commit -a -m "{0}"' -f $SquashCommitMessage }
            'switch'  { "switch $SwitchBranch"                      }
        }

        foreach ($cmd in $commands) {
            Write-Host "Executing: $cmd"
            $cmdArgs = if ( $cmd -match '\s' ) {
                $cmd.Trim() -split '\s+'
            } else {
                $cmd
            }

            git @cmdArgs
        }
    }
}

#git diff (need to create a hashtable of commits to reference by index with first line of commit message as description on tab completion)