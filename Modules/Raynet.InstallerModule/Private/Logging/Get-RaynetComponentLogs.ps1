<#
.SYNOPSIS
    Returns sanitized log file paths for a Raynet component.

.DESCRIPTION
    Component logs are stored directly in the detail-log directory supplied by
    Invoke-RaynetPackage. No additional per-component subfolder is created.

.PARAMETER Component
    Component definition.

.PARAMETER LogRoot
    Detail-log directory for the current main installer script.

.PARAMETER Action
    Effective Install or Uninstall action.

.NOTES
    Raynet Installer Framework 0.4.
#>
function Get-RaynetComponentLogs {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][string]$Action
    )

    $safeName = ConvertTo-RaynetSafePathName -Name ([string]$Component.Name)
    $safeAction = ConvertTo-RaynetSafePathName -Name ([string]$Action)

    return @{
        WrapperLog = Join-Path $LogRoot ("{0}_{1}.log" -f $safeName, $safeAction)
        MsiLog     = Join-Path $LogRoot ("{0}_{1}_MSI.log" -f $safeName, $safeAction)
    }
}
