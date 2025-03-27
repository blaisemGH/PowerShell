using namespace System.IO

class IStructuredData {

    IStructuredData(){
        if ( $this.GetType() -eq [IStructuredData] ) {
            throw("Cannot instantiate object of type IStructuredData. This type is an interface only.")
        }
    }

    [PSCustomObject]Import([string]$filePath) {
        throw("Method Import() has been inherited from the interface IStructuredData. This method must be overridden!")
    }
    [PSCustomObject]Import([FileInfo]$filePath) {
        throw("Method Import() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

    [void] Export([object]$inputObject, [string]$filePath) {
        throw("Method Export() has been inherited from the interface IStructuredData. This method must be overridden!")
    }
    [void] Export([object]$inputObject, [string]$filePath, [bool]$append) {
        throw("Method Export() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

    [PSCustomObject] ConvertFrom([string[]]$inputString) {
        throw("Method ConvertFrom() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

    [string[]] ConvertTo([object[]]$inputObject) {
        throw("Method ConvertTo() has been inherited from the interface IStructuredData. This method must be overridden!")
    }

}