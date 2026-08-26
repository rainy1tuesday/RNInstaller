<#
.SYNOPSIS
    Loads the Raynet Installer framework configuration.
.DESCRIPTION
    Reads Public\Config\RaynetInstaller.ini. Missing values fall back to
    framework defaults.
.PARAMETER ConfigPath
    Optional explicit configuration file path.
#>
function Get-RaynetConfiguration {
    [CmdletBinding()]
    param(
        [string]$ConfigPath
    )

    if ([string]::IsNullOrWhiteSpace($ConfigPath)) {
        $moduleRoot = $script:RaynetModuleRoot
        if ([string]::IsNullOrWhiteSpace($moduleRoot)) { $moduleRoot = $raynetRoot }
        if ([string]::IsNullOrWhiteSpace($moduleRoot)) { $moduleRoot = Split-Path -Parent $PSScriptRoot }
        $ConfigPath = Join-Path $moduleRoot 'Public\Config\RaynetInstaller.ini'
    }

    $config = @{
        Paths = @{
            LogRoot       = 'C:\ProgramData\Raynet\Intune\Apps\Logs'
            DetectionRoot = 'HKLM:\Software\Raynet\IntuneDetection'
        }
        Logging = @{
            Level               = 'INFO'
            PackageSubdirectory = $true
            ComponentLogs       = $true
        }
        Framework = @{
            CreateMissingDirectories = $true
        }
    }

    if (-not (Test-Path -LiteralPath $ConfigPath -PathType Leaf)) {
        return $config
    }

    $section = ''
    foreach ($raw in Get-Content -LiteralPath $ConfigPath -ErrorAction Stop) {
        $line = $raw.Trim()
        if (-not $line) { continue }
        if ($line.StartsWith(';') -or $line.StartsWith('#')) { continue }

        if ($line -match '^\[(.+)\]$') {
            $section = $Matches[1]
            continue
        }

        if ($line -notmatch '^([^=]+)=(.*)$') { continue }

        $key = $Matches[1].Trim()
        $value = $Matches[2].Trim()
        if (-not $config.ContainsKey($section)) {
            $config[$section] = @{}
        }
        if ($value -match '^(?i:true|false)$') {
            $value = [bool]::Parse($value)
        }
        $config[$section][$key] = $value
    }

    return $config
}
