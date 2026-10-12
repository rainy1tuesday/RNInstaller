function New-RaynetComponentResult {
    param(
        [Parameter(Mandatory)][bool]$Success,
        [Parameter(Mandatory)][int]$ExitCode,
        [string]$FailureReason,
        [string]$ErrorMessage,
        [bool]$Skipped = $false,
        [bool]$AlreadyInDesiredState = $false,
        [bool]$RebootRequired = $false,
        [hashtable]$Data
    )

    $result = [ordered]@{
        Success = $Success
        ExitCode = $ExitCode
        Error = $FailureReason
        ErrorMessage = $ErrorMessage
        Skipped = $Skipped
        AlreadyInDesiredState = $AlreadyInDesiredState
        RebootRequired = $RebootRequired
    }
    if ($Data) { foreach ($key in $Data.Keys) { $result[$key] = $Data[$key] } }
    [pscustomobject]$result
}
