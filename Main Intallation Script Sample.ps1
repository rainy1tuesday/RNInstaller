<#
.SYNOPSIS
    Intune Win32App package: Main Installation Script Sample

.DESCRIPTION
    This script is a reusable Raynet Installer package definition for Intune Win32App
    deployments. The package script describes WHAT should happen; the Raynet Installer
    framework provides HOW components are executed.

    Framework features include:
    - Install and uninstall package actions
    - Component-specific action overrides through -Opt_Action
    - Critical/non-critical components through -Opt_Critical
    - Detailed package and component logging
    - Reboot propagation (for example MSI exit code 3010)
    - Registry detection state for Intune
    - Native PowerShell component help (`Get-Help`)
    - Convention-based plugin components
    - External framework configuration through Public\Config\RaynetInstaller.ini

    Package authors should normally change only the application metadata and the
    Raynet_* component definitions below.

.PARAMETER Action
    Defines the package action to run.
    Accepted values:
    - Install
    - Uninstall







.NOTES
    Script Name : Main Installation Script Sample.ps1
    App Name    : Main Installation Script Sample
    Version     : 1.0.0
    Author      : Martin Appel
    Created     : 2026-08-11
    Revision    : 1.0
    Framework   : Raynet Installer 0.4


#>

[CmdletBinding()]
param(
    [ValidateSet('Install','Uninstall')]
    [string]$Action = 'Install'
)

$ErrorActionPreference='Stop'
Import-Module "$PSScriptRoot\Modules\Raynet.InstallerModule\Raynet.InstallerModule.psm1" -Force
$AppName='Main Installation Script Sample'
$AppVersion='1.0'
$PackageRevision='1.0'

Initialize-RaynetPackage -Action $Action

# ================================================================================
# Package-specific components. This is the only section normally changed for a
# new Intune package.
# ================================================================================

Raynet_ConfigureService `
    -Name 'Disable esiCore Service' `
    -ServiceName 'esicore' `
    -Opt_Configure_StartType 'Disabled' `
    -Opt_Critical $false

Raynet_Service `
    -Name 'Stop DSM Core Service' `
    -ServiceName 'esiCore' `
    -ServiceAction 'stop' `
    -Opt_Critical $false

Raynet_Service `
    -Name 'Stop DSM Runtime Service' `
    -ServiceName 'ersupext' `
    -ServiceAction 'stop' `
    -Opt_Critical $false

Raynet_RegModify `
    -Name 'Disable NIAMH.dll' `
    -RegistryPath 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows NT\CurrentVersion\Windows' `
    -ValueName 'AppInit_DLLs' `
    -RegistryAction 'Set' `
    -ValueType 'REG_SZ' `
    -ValueData ''

Raynet_Process `
    -Name 'Stop Explorer' `
    -ProcessName 'explorer.exe'

Raynet_ScheduledTask `
    -Name 'Restart Explorer' `
    -TaskName 'Raynet_RestartExplorer' `
    -Opt_Description 'Restarts the Windows Explorer process' `
    -Execute 'explorer.exe' `
    -TriggerType 'Immediate' `
    -Opt_RunAs 'LoggedOnUser' `
    -Opt_RemoveAfterRun $true

Raynet_Process -Name 'Stop DSMC' -ProcessName 'dsmc.exe'
Raynet_Process -Name 'Stop NIAgent' -ProcessName 'NiAgnt32.exe'
Raynet_Process -Name 'Stop eTray' -ProcessName 'etray.exe'
Raynet_Process -Name 'Stop Software Shop' -ProcessName 'SoftwareShop.exe'
Raynet_Process -Name 'Stop NiInst' -ProcessName 'niinst32.exe'

Raynet_DeleteFiles `
    -Name 'Remove NI agent' `
    -TargetFolder 'C:\Program Files (x86)\Netinst' `
    -FilePattern '*.*' `
    -Opt_DeleteEmptyDirectories $true

Raynet_DeleteFiles `
    -Name 'MsCreate.dir' `
    -TargetFolder 'C:\Program Files (x86)\Netinst' `
    -FilePattern 'MsCreate.dir' `
    -Opt_DeleteEmptyDirectories $true

Raynet_DeleteFiles `
    -Name 'Remove NI Data' `
    -TargetFolder 'C:\Program Files (x86)\Common Files\enteo' `
    -FilePattern '*.*' `
    -Opt_DeleteEmptyDirectories $true

$result=Invoke-RaynetPackage `
    -Action $Action `
    -AppName $AppName `
    -AppVersion $AppVersion `
    -PackageRevision $PackageRevision `
    -Components (Get-RaynetComponents)

exit $result.ExitCode
