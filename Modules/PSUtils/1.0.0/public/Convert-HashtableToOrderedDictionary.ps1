using namespace System.Collections.Specialized
Function Convert-HashtableToOrderedDictionary {
	[OutputType(OrderedDictionary)]
	Param(
		[Parameter(Mandatory,ValueFromPipeline)]
		[hashtable]$Hashtable
	)
	begin {
		$outOrderedDict = [ordered]@{}
	}
	process {
		$keys = $Hashtable.Keys
		$sortedKeys = Sort-Object $keys
		$sortedKeys.foreach({
			$outOrderedDict.Add($_, $Hashtable[$_])
		})
	}
	end {
		$outOrderedDict
	}
}