<#
    .SYNOPSIS
        A function I am still working on that is a wraper for the git cli tool. Specifically it is for streamlining the handling of branches: creation, committing, pushing, and deleting branches.
        
        I mostly missed having autocomplete and didn't like remembering some arbitrary hard-coded values. This function is a WIP to possibly simplify this.
        Line 65 contains the current usage setup.
#>

Function Use-GitCliForBranch {
    [CmdletBinding(DefaultParameterSetName='list')]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, ParameterSetName='pull')]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                [string[]](git branch -r) | Where-Object {
                    $_ -like "$wordToComplete*"
                }
            }
        )]
        [Alias('pb')]
        [string]$PullBranch,
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='create')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='delete')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='checkout')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='rename')]
        [Parameter(ValueFromPipeline, Position = 0, ParameterSetName='push')]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                [string[]]@((git branch) -replace '\*' -replace '\s') | Where-Object {
                    $_ -like "$wordToComplete*"
                }
            }
        )]
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
        [string]$SquashCommitMessage
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
        $cmd = Switch ($PSCmdlet.ParameterSetName) {
            'create'    { "git checkout -b $BranchName"        }
            'delete'    { "git branch -D $BranchName"        }
            'checkout'    { "git checkout $BranchName"            }
            'list'        { "git branch"                        }
            'commit'    { 'git commit -a -m "{0}"' -f $CommitMessage }
            'push'        { "git push --set-upstream origin $currentBranch" }
            'rename'    { "git branch -m $BranchName $RenamedBranchName"}
            'squash'    { git reset --soft $SquashToCommitId; 'git commit -a -m "{0}"' -f $SquashCommitMessage }
        }
        Write-Host "Executing: $cmd"
        Invoke-Expression $cmd
    }
}

#git reset --hard origin/develop
#git rebase
#git merge
#git diff (need to create a hashtable of commits to reference by index with first line of commit message as description on tab completion)