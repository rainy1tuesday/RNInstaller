<#
.SYNOPSIS
    Resolves a component Type to its implementation function.
.DESCRIPTION
    Uses naming convention only: Type X -> Invoke-RaynetX.
#>
function Resolve-RaynetComponentCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Type)

    $commandName = "Invoke-Raynet$Type"
    $command = Get-Command -Name $commandName -CommandType Function -ErrorAction SilentlyContinue
    if (-not $command) {
        throw "No Raynet component implementation found for Type [$Type]. Expected [$commandName]."
    }
    return $command
}
