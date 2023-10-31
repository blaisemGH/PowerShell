# Function for checking file hashes using the Windows built-in CertUtil.exe program.
Function Out-FileHash {
	Param(
		[Parameter(Mandatory,ValueFromPipeline, ValueFromPipelineByPropertyName)]
		[Alias('PSPath')]
		[string]$Path,

		[Parameter(Mandatory)]
		[FileHashes]$Algorithm
	)
	Process {
		CertUtil -hashfile $Path $Algorithm
	}
}