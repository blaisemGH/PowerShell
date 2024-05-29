function Add-GKECredentials {
    [CmdletBinding(DefaultParameterSetName = 'ViaProjectID' )]
    Param(
        [Parameter(ParameterSetName = 'ViaProjectID' )]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                (gcloud projects list) -replace '\s{2,}', [char]0x2561 | 
                    ConvertFrom-Csv -Delimiter ([char]0x2561) | Where {
                        ($_.Name -replace '\s') -like ("$wordToComplete*" -replace '\s')
                    } | Sort-Object Name | Select-Object -expandProperty Name | % { $_ -replace '\s'}
            }
        )]
        [Alias('filter')]
        [string]$NameFilter,

        [Parameter(Mandatory, ParameterSetName = 'ViaProjectID')]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                $namefilter = if ( $fakeBoundParameters.NameFilter ) { $fakeBoundParameters.NameFilter} else { '*' }
                (gcloud projects list) -replace '\s{2,}', [char]0x2561 | 
                    ConvertFrom-Csv -Delimiter ([char]0x2561) | Where {
                        ($_.Name -replace '\s') -like $nameFilter -and $_.Project_ID -like "$wordToComplete*"
                    } | Select-Object -exp Project_ID
            }
        )]
        [string]$ProjectID,

        [Parameter(Mandatory, ParameterSetName = 'ViaLocalFilesystem', ValueFromRemainingArguments )]
        [ArgumentCompleter(
            {
                param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
                Get-ChildItem ([GCloud]::ProjectRoot) -Recurse -Name -File | Where-Object { 
                    (Split-Path $_ -Leaf) -like "$wordToComplete*" -or
                    (Split-Path $_ -Parent) -like "$wordToComplete*"
                } | ForEach-Object { $_ -replace '\s' }
            }
        )]
        [string]$IDFromFS,

        [Alias('key')]
        [string]$NewMapKey
    )

    $selectedProjectID = & {
        if ($PSCmdlet.ParameterSetName -eq 'ViaLocalFilesystem') {
            Split-Path ($IDFromFS -join '') -Leaf
        } else {
            $ProjectID
        }
    }

    $clusterGKEInfo = (gcloud container clusters list --project $selectedProjectID) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)

    if ( ! $clusterGKEInfo.Name ) {
        $err = [System.Management.Automation.ErrorRecord]::new("Empty output from command: gcloud container clusters list --project $selectedProjectID", $null, 'ObjectNotFound', $null)
        $PSCmdlet.ThrowTerminatingError($err)
    }
    
    gcloud container clusters get-credentials $clusterGKEInfo.Name --location $clusterGKEInfo.Location --project $selectedProjectID
    
    if ( $? ) {
        Update-ContextFileMap -ProjectID $selectedProjectID -NewMapKey $NewMapKey -ErrorAction Stop | Export-ContextFileAsPSD1
        
        gcloud config set project $selectedProjectID
        [GCloud]::CurrentProject = $selectedProjectID
    }
}
