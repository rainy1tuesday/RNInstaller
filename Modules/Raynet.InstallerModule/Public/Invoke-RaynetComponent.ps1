<#
.SYNOPSIS
    Dispatches a Raynet component dynamically.
.DESCRIPTION
    Resolves Type X to Invoke-RaynetX. No central registration table is used.
#>
function Invoke-RaynetComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )

    $command = Resolve-RaynetComponentCommand -Type ([string]$Component.Type)
    & $command.Name -Component $Component -LogRoot $LogRoot -Action $Action
}
