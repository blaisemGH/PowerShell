using namespace System.Management.Automation
# For use as input into $PSCmdlet.ThrowTerminatingError(<[ErrorRecord]>), which is better than throw
# but only takes an ErrorRecord as input argument..
function New-ErrorRecord {
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [string]$ExceptionText,
        [string]$ErrorId,
        [ErrorCategory]$ErrorCategory = 'NotSpecified',
        [object]$TargetObject
    )

    process {
        return [ErrorRecord]::new($ExceptionText, $ErrorId, $ErrorCategory, $TargetObject)
    }
}