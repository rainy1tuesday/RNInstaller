<#
.SYNOPSIS
    Initializes and stores package component definitions.
#>
function Initialize-RaynetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Install','Uninstall')]
        [string]$Action
    )

    $script:RaynetPackageAction = $Action
    $script:RaynetComponents = [System.Collections.Generic.List[hashtable]]::new()

    if ($MyInvocation.ScriptName) {
        $script:RaynetPackageScript = [IO.Path]::GetFullPath($MyInvocation.ScriptName)
        $script:RaynetPackageRoot = Split-Path -Parent $script:RaynetPackageScript
    }
}

function Add-RaynetComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Component
    )

    if (-not $script:RaynetComponents) {
        $script:RaynetComponents = [System.Collections.Generic.List[hashtable]]::new()
    }

    if ($script:RaynetPackageRoot) {
        $Component['_PackageRoot'] = $script:RaynetPackageRoot
    }

    foreach ($propertyName in @('SourceFile','MsiPath','Transform','ExePath','UninstallExePath','IniFile','FileName','SqlFile')) {
        if (-not $Component.ContainsKey($propertyName)) { continue }
        $value = [string]$Component[$propertyName]
        if ([string]::IsNullOrWhiteSpace($value)) { continue }

        $expanded = [Environment]::ExpandEnvironmentVariables($value)
        if ([IO.Path]::IsPathRooted($expanded) -or $expanded.StartsWith('\\')) {
            $Component[$propertyName] = $expanded
            continue
        }

        if ($script:RaynetPackageRoot) {
            $Component[$propertyName] = [IO.Path]::GetFullPath(
                (Join-Path $script:RaynetPackageRoot $expanded)
            )
        }
    }

    $script:RaynetComponents.Add($Component)
}

function Get-RaynetComponents {
    return @($script:RaynetComponents)
}
