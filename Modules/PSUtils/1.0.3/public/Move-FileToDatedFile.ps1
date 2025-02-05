Function Move-FileToDatedFile {
    param(
        [Parameter(Mandatory,ValueFromPipelineByPropertyName)]
        [Alias('PSPath','LP')]
        [string]$FilePath,
        [datetime]$Date,
        [string]$DateFormat = '_yyyy-MM-dd_HH-mm-ss-fff'
    )
    begin {
        $newDatetime = if ( $Date ) { $Date } else { Get-Date }
    }
    process {
        $outputFileItem = Get-Item $outputFile
        $rollOverFilename = $outputFileItem.BaseName + $newDatetime.ToString($DateFormat) + $outputFileItem.Extension
        Move-Item -LiteralPath $outputFile -Destination $rolledoverFilename
    }
}