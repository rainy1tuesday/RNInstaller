<#
.SYNOPSIS
    Writes a Raynet Installer log entry.
#>
function Write-RaynetInstallerLog {
    param(
        [Parameter(Mandatory)][string]$LogFile,
        [Parameter(Mandatory)][string]$Message,
        [ValidateSet('DEBUG','INFO','SUCCESS','WARNING','ERROR')]
        [string]$Level = 'INFO'
    )

    $configuredLevel = if ($script:RaynetConfiguredLogLevel) {
        [string]$script:RaynetConfiguredLogLevel
    }
    else {
        'INFO'
    }

    $rank = @{
        DEBUG   = 10
        INFO    = 20
        SUCCESS = 25
        WARNING = 30
        ERROR   = 40
    }

    if (-not $rank.ContainsKey($configuredLevel)) {
        $configuredLevel = 'INFO'
    }

    if ($rank[$Level] -lt $rank[$configuredLevel]) {
        return
    }

    $parent = Split-Path -Parent $LogFile
    if ($parent -and -not (Test-Path -LiteralPath $parent)) {
        New-Item -Path $parent -ItemType Directory -Force -ErrorAction Stop | Out-Null
    }

    $line = '{0} [{1}] {2}' -f (Get-Date -Format 'yyyy-MM-dd HH:mm:ss.fff'), $Level, $Message

    $parent = Split-Path -Parent $LogFile
    if (-not [string]::IsNullOrWhiteSpace($parent) -and
        -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
    }

    Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8

    if ($Level -ne 'DEBUG') {
        Write-Host $line
    }
}
