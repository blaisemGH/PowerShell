using namespace System.Collections.Generic
using namespace System.IO
class ConfigFileUtils {
    ConfigFileUtils([string]$filename) {
        
    }
    ConfigFileUtils([FileInfo]$filename) {
        
    }

    static [object] SetFileTypeUsingExtension ([string]$extension) {
        return switch -Regex ($extension) {
            ^.ya?ml$ {}
            ^.jso?n$ {}
            ^.csv$ {}
            ^.ini$ {}
            ^.xml$ {}
            ^.properties$ {}
            ^.txt$ {}
            ^.to?ml$ {}
            ^.psd1$ {}
            ^.ps1$ {}
        }
    }
    static [pscustomobject] ConvertFromGenericDictionary ([Dictionary[object, object]]$dictionary) {
        $obj = [PSCustomObject][hashtable]$dictionary
        Foreach ($entry in $dictionary.GetEnumerator()) {
            $value = if ( $entry.Value -is [Dictionary[object,object]]) {
                [ConfigFileUtils]::ConvertFromGenericDictionary($entry.Value)
            }
            elseif ( $entry.Value -is [KeyValuePair[object,object]]) {
                [ConfigFileUtils]::ConvertFromGenericDictionary($_.Value)
            }
            else {
                $entry.Value
            }
            $obj.($entry.Key) = $value
        }
        return $obj
    }
}
