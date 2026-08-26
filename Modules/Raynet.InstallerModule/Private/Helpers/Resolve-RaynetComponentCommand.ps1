function Resolve-RaynetComponentCommand {
    [CmdletBinding()]
    param([Parameter(Mandatory)][string]$Type)
    $name = "Invoke-Raynet$Type"
    $cmd = Get-Command -Name $name -CommandType Function -ErrorAction SilentlyContinue
    if (-not $cmd) {
        throw "No implementation found for component Type [$Type]. Expected function [$name]."
    }
    return $cmd
}
