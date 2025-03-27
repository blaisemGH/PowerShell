using namespace System.IO
class NewStructuredDataType {

    static [IStructuredData] GetDataTypeByFileExtension([string]$filePath) {
        $utilType = [NewStructuredDataType]::GetDataType((Get-Item $filePath -ErrorAction Stop).Extension)
        $utilType.FilePath = $filePath
        return $utilType
        
    }
    static [IStructuredData] GetDataTypeByFileExtension([FileInfo]$file) {
        $utilType = [NewStructuredDataType]::GetDataType($file.Extension)
        $utilType.FilePath = $file.FullName
        return $utilType
    }

    static [IStructuredData] GetDataType ([string]$extension) {
        return switch -Regex ($extension) {
            ^\.?ya?ml$ { [YamlData]::new($false) }
            ^\.?jso?n$ {}
            ^\.?csv$ {}
            ^\.?ini$ {}
            ^\.?xml$ {}
            ^\.?properties$ {}
            ^\.?txt$ {}
            ^\.?to?ml$ {}
            ^\.?psd1$ {}
            ^\.?ps1$ {}
            DEFAULT { throw "Could not recognize extension: $extension" }
        }
    }
}