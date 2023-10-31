Function Add-GKECredentials {
	Param(
		[Parameter(Mandatory)]
		[ArgumentCompleter(
			{
				param($commandName, $parameterName, $wordToComplete, $commandAst, $fakeBoundParameters)
				(gcloud projects list) -replace '\s{2,}', [char]0x2561 | 
					ConvertFrom-Csv -Delimiter ([char]0x2561) |
					Select-Object -ExpandProperty PROJECT_ID |
					Where-Object {
						$_ -like "$wordToComplete*"
					}
			}
		)]
		[Alias('Name')]
		[string]$ProjectName
	)

	$clusterGKEInfo = (gcloud container clusters list --project $ProjectName) -replace '\s{2,}', [char]0x2561 | ConvertFrom-Csv -Delimiter ([char]0x2561)

	gcloud container clusters get-credentials $clusterGKEInfo.Name --location $clusterGKEInfo.Location --project $ProjectName
	Update-ContextFileMap -ProjectName $ProjectName -ErrorAction Stop | Export-ContextFileAsPSD1
}