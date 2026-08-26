<#
.SYNOPSIS
    Writes the package-run header to the main log.
#>
function Write-RaynetPackageHeader {
    param(
        [Parameter(Mandatory)][string]$LogFile,
        [Parameter(Mandatory)][string]$Action,
        [Parameter(Mandatory)][string]$ScriptPath,
        [Parameter(Mandatory)][string]$AppName,
        [string]$AppVersion,
        [string]$PackageRevision
    )

    try {
        $userName = [System.Security.Principal.WindowsIdentity]::GetCurrent().Name
    }
    catch {
        $userName = "$env:USERDOMAIN\$env:USERNAME"
    }

    $parent = Split-Path -Parent $LogFile
    if (-not [string]::IsNullOrWhiteSpace($parent) -and
        -not (Test-Path -LiteralPath $parent -PathType Container)) {
        New-Item -ItemType Directory -Path $parent -Force -ErrorAction Stop | Out-Null
    }


    foreach ($line in @(
        '==============================================================================',
        'Raynet Installer - Script started',
        '==============================================================================',
        ('Timestamp        : {0:yyyy-MM-dd HH:mm:ss}' -f (Get-Date)),
        ('Action           : {0}' -f $Action),
        ('Component source : {0}' -f $ScriptPath),
        ('User             : {0}' -f $userName),
        ('Computer         : {0}' -f $env:COMPUTERNAME),
        ('Application      : {0}' -f $AppName),
        ('Version          : {0}' -f $AppVersion),
        ('Revision         : {0}' -f $PackageRevision),
        '=============================================================================='
    )) {
        Add-Content -LiteralPath $LogFile -Value $line -Encoding UTF8
    }
}
