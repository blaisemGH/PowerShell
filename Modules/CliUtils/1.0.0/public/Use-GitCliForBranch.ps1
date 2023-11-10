<#
    .SYNOPSIS
        A function I am still working on that is a wraper for the git cli tool. Specifically it is for streamlining the handling of branches: creation, committing, pushing, and deleting branches.
        
        I mostly missed having autocomplete and didn't like remembering some arbitrary hard-coded values. This function is a WIP to possibly simplify this.
        Line 65 contains the current usage setup.
#>

Function Use-GitCliForBranch {
    [CmdletBinding(DefaultParameterSetName='list')]
    Param(
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='create')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='delete')]
        [Parameter(Mandatory, ValueFromPipeline, Position = 0, ParameterSetName='checkout')]
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
        [switch]$Push,
        [Parameter(Mandatory, ParameterSetName='commit')]
        [Alias('c')]
        [string]$CommitMessage
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
        $cmd = Switch ($PSCmdlet.ParameterSetName) {
            'create'    { "git checkout -b $BranchName"        }
            'delete'    { "git branch -D $BranchName"        }
            'checkout'    { "git checkout $BranchName"            }
            'list'        { "git branch"                        }
            'commit'    { 'git commit -a -m "{0}"' -f $CommitMessage }
            'push'        { "git push --set-upstream origin $currentBranch" }
        }
        Write-Host "Executing: $cmd"
        Invoke-Expression $cmd
    }
}
