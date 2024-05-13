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

    static [pscustomobject] ConvertToGenericDictionary ([PSCustomObject]$psobject) {
        <#
        $props = $psobject.psobject.properties
        if ( $props.Count -eq 1 ) {
            [KeyValuePair]::Create($props, $psobject.$props)
        }
        else {
            
        }#>
        Foreach ($property in $psobject.psobject.properties) {
            $value = $psobject.$property
            if ( $value -is [IList] ) {
                
            }
            $value = if ( $psobject.property -is [Dictionary[object,object]]) {
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
