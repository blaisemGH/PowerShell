using namespace System.Management.Automation
# For use as input into $PSCmdlet.ThrowTerminatingError(<[ErrorRecord]>), which is better than throw
# but only takes an ErrorRecord as input argument..
function New-ErrorRecord {
    [OutputType([System.Management.Automation.ErrorRecord])]
    param(
        # This is an exception which describes the error. This argument may not be null, but it is not required that the exception have ever been thrown.
        [Parameter(Mandatory, ValueFromPipeline, Position=0)]
        [string]$ExceptionText,

        # This string will be used to construct the FullyQualifiedErrorId, which is a global identifier of the error condition. Pass a non-empty string which is specific to this error condition in this context.
        [string]$ErrorId,
        
        # This is the ErrorCategory which best describes the error. Valid values:
        # AuthenticationError, CloseError, ConnectionError, DeadlockDetected, DeviceError, FromStdErr, InvalidArgument, InvalidData, InvalidOperation, InvalidResult, InvalidType, LimitsExceeded, MetadataError, NotEnabled, NotImplemented, NotInstalled, NotSpecified, ObjectNotFound, OpenError, OperationStopped, OperationTimeout, ParserError, PermissionDenied, ProtocolError, QuotaExceeded, ReadError, ResourceBusy, ResourceExists, ResourceUnavailable, SecurityError, SyntaxError, WriteError
        [ErrorCategory]$ErrorCategory = 'NotSpecified',

        # This is the object against which the cmdlet or provider was operating when the error occurred. This is optional.
        [object]$TargetObject
    )

    process {
        return [ErrorRecord]::new($ExceptionText, $ErrorId, $ErrorCategory, $TargetObject)
    }
}