Function Get-UnattachedDisks {
    param(
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='ByProjectID')]
        [string[]]$ProjectIDs,
        [Parameter(Mandatory,ValueFromPipeline,ParameterSetName='AllFromFS')]
        [IO.FileSystemInfo[]]$PathsInGoogleProvider,
        [string]$FilterProjectIDs,
        [string]$FilterDiskNames
    )
    begin {
        $script:unattachedDisks = [Collections.Generic.List[object]]::new()
    }
    process {
        If ( $PSCmdlet.ParameterSetName -eq 'ByProjectID' ) { write-host 'yes'
            Foreach ( $project in ($ProjectIDs | Where $_ -match $FilterProjectIDs) ) {
                Write-Host $project -Fore Yellow
                $userDisks = gcloud compute disks list --filter="users:*" --project $project | ConvertFrom-StringTable | where NAME -match $FilterDiskNames
                $allDisks = gcloud compute disks list --project $project | ConvertFrom-StringTable | where {$_.NAME -match $FilterDiskNames -and $_.NAME -notin $userDisks.Name}
                $allDisks | % { $_ | Add-Member -Name Project -Value $project -MemberType NoteProperty }
                
                try {
                    $script:unattachedDisks.AddRange($allDisks)
                } catch [System.Management.Automation.MethodInvocationException] {}
            }
        }
        If ( $PSCmdlet.ParameterSetName -eq 'AllFromFS' ) {
            Foreach ( $path in $PathsInGoogleProvider ) {
                Get-ChildItem $path -Recurse -File | Where name -match $FilterProjectIDs | Foreach {
                    $folder = Split-Path $_ -Parent | Split-Path -Leaf
                    $project = Split-Path $_ -Leaf
                    Write-Host $folder -Fore Cyan -NoNewLine; Write-Host ' - ' -NoNewLine; Write-Host $project -Fore Yellow

                    $userDisks = gcloud compute disks list --filter="users:*" --project $project | ConvertFrom-StringTable | where NAME -match $FilterDiskNames
                    $allDisks = gcloud compute disks list --project $project | ConvertFrom-StringTable | where {$_.NAME -match $FilterDiskNames -and $_.NAME -notin $userDisks.Name}
                    $allDisks | % { $_ | Add-Member -Name Folder -Value $folder -MemberType NoteProperty  }
                    $allDisks | % { $_ | Add-Member -Name Project -Value $project -MemberType NoteProperty }
                    try {
                        $script:unattachedDisks.AddRange($allDisks)
                    } catch [System.Management.Automation.MethodInvocationException] {}
                }
            }
        }
        
    }
    end {
        Write-Host 'Unsorted output saved in variable $unattachedDisks. Recommend to sort and view it with Format-Table, $unattachedDisks | sort { [int]$_.SIZE_GB } | ft'
        $script:unattachedDisks | Sort-Object { [int]$_.Size_gb }
    }
}