$completionsConfigDir = [GCloudCompletion]::CompletionsWorkDir

if ( ! (Test-Path $completionsConfigDir) ){
    New-Item -it Directory $completionsConfigDir
}

$markerOfLocation = Join-Path $completionsConfigDir fileLocation.txt
if ( ! (Test-Path $markerOfLocation ) ) {
    "$(gcloud info --format="value(installation.sdk_root)")/data/cli/gcloud_completions.py" > $markerOfLocation
}

$pyCompletionLocation = Get-Content $markerOfLocation
if ( $pyCompletionLocation -match 'gcloud_completions.py$' -and ! (Test-Path $pyCompletionLocation)){
    "$(gcloud info --format="value(installation.sdk_root)")/data/cli/gcloud_completions.py" > $markerOfLocation
}

[GCloudCompletion]::CompletionFilepath = (Get-Content $markerOfLocation)

Register-GCloudCompletion