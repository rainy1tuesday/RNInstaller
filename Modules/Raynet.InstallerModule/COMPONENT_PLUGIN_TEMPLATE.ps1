<#
.SYNOPSIS
    Template for a Raynet 0.4 single-file component.
#>

function Raynet_X {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [ValidateSet('Default','Install','Uninstall')][string]$Opt_Action = 'Default',
        [bool]$Opt_Critical = $true
    )

    Add-RaynetComponent @{
        Type = 'X'
        Name = $Name
        Opt_Action = $Opt_Action
        Opt_Critical = $Opt_Critical
    }
}

function Invoke-RaynetX {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )

    # Implementation
}
