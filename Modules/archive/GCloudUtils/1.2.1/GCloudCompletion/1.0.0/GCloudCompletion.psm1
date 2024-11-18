#Set-GCloudCompletion -ModuleHome $PSScriptRoot

#$j = '{' + (gc C:\Users\MullenixJohn\Programs\gcloud\google-cloud-sdk\data\cli\gcloud_completions.py | select -skip 4)| cfj -AsHashtable

$completionsConfigDir = "$HOME/.pwsh/gcloud/completions" 
if ( ! (Test-Path $completionsConfigDir) ){
    New-Item -it Directory $completionsConfigDir
}

$markerOfLocation = Join-Path $completionsConfigDir fileLocation.txt
if ( ! (Test-Path $markerOfLocation ) ) {
    "$(gcloud info --format="value(installation.sdk_root)")/data/cli/gcloud_completions.py" > $markerOfLocation
}

$pyCompletionLocation = Get-Content $markerOfLocation
if ( ! (Test-Path $pyCompletionLocation) -and $pyCompletionLocation -match 'gcloud_completions.py$'){
    "$(gcloud info --format="value(installation.sdk_root)")/data/cli/gcloud_completions.py" > $markerOfLocation
}
<#
[GcloudSdkCompleter]::CompletionFilepath = (Get-Content $markerOfLocation)
function g {
    param(
        [Parameter(DontShow, ValueFromRemainingArguments)]
        [GCloudSdkCompletions()]
        [string[]]$gcloud
    )

    $gcloudSdkArgs = $gcloud -replace '\s{2,}', ' ' -split ' '

    & ([GCloudSdkCompleter]::gcloudDotPs1Path) @gcloudSdkArgs
}
#>

[GcloudCompletions]::CompletionFilepath = (Get-Content $markerOfLocation)

Register-GCloudCompletion