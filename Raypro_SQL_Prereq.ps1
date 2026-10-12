<#
.SYNOPSIS
    Installs or uninstalls the RayPro SQL prerequisites.

.DESCRIPTION
    Raynet Installer package for the SQL prerequisite MSI packages. Installers,
    detection, component logging, reboot handling, and registry state are managed
    by the Raynet.InstallerModule framework.

.PARAMETER Action
    Package action: Install or Uninstall.

.NOTES
    MSI source files and the optional transform are expected under .\Files.
    Run elevated; MSI installation and framework detection state require
    administrative privileges.
#>
[CmdletBinding()]
param(
    [ValidateSet('Install','Uninstall')]
    [string]$Action = 'Install'
)

$ErrorActionPreference = 'Stop'

Import-Module (Join-Path $PSScriptRoot 'Modules\Raynet.InstallerModule\Raynet.InstallerModule.psm1') -Force

$AppName = 'RayPro_SQL_Prereqs'
$AppVersion = '1.0'
$PackageRevision = '1.0'

$MsiPackages = @(
    @{
        Name = 'Synchronization-KB2703853-v2.1-x86-ENU'
        MsiPath = 'Synchronization-KB2703853-v2.1-x86-ENU.msi'
        ProductCode = '{67BAD5BC-0F33-4808-83AA-A317D442ADAA}'
        InstallArgs = '/qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'Synchronization-KB2703853-v2.1-x64-ENU'
        MsiPath = 'Synchronization-KB2703853-v2.1-x64-ENU.msi'
        ProductCode = '{973B9FF6-B6F0-49CE-A5E8-A13797A86807}'
        InstallArgs = '/qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'ProviderServices-KB2703853-v2.1-x86-ENU'
        MsiPath = 'ProviderServices-KB2703853-v2.1-x86-ENU.msi'
        ProductCode = '{5499F6A7-8F4D-4A41-8FDC-F3B2D9786D5F}'
        InstallArgs = '/qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'ProviderServices-KB2703853-v2.1-x64-ENU'
        MsiPath = 'ProviderServices-KB2703853-v2.1-x64-ENU.msi'
        ProductCode = '{2FD91588-8637-446B-8C85-5E1822AE7EBB}'
        InstallArgs = '/qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'DatabaseProviders-KB2703853-v3.1-x64-ENU'
        MsiPath = 'DatabaseProviders-KB2703853-v3.1-x64-ENU.msi'
        ProductCode = '{8FA72768-1B02-46AF-9DC8-8942EEC5BA10}'
        InstallArgs = '/qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'DatabaseProviders-KB2703853-v3.1-x86-ENU'
        MsiPath = 'DatabaseProviders-KB2703853-v3.1-x86-ENU.msi'
        ProductCode = '{C41C4D09-6C05-42B1-951D-8F0DE6B1553D}'
        InstallArgs = '/qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'MsSqlCmdLnUtils'
        MsiPath = 'MsSqlCmdLnUtils.msi'
        ProductCode = '{6F11B2D6-193B-4216-A8E6-D7092834F8FB}'
        InstallArgs = 'IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES /qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
    @{
        Name = 'MsODBCSql'
        MsiPath = 'MsODBCSql.msi'
        ProductCode = '{0E0F96AC-80DE-4400-A40C-429D63293651}'
        Transform = 'MsODBCSql2.mst'
        InstallArgs = 'IACCEPTMSSQLCMDLNUTILSLICENSETERMS=YES /qn /norestart'
        UninstallArgs = '/qn /norestart'
        ForceInstallMode = 'Default'
    }
)

Initialize-RaynetPackage -Action $Action

foreach ($package in $MsiPackages) {
    # The legacy package used ForceInstallMode only during install. On uninstall,
    # every MSI was uninstalled in reverse order regardless of that setting.
    $componentAction = if ($Action -eq 'Uninstall') {
        'Default'
    }
    else {
        $package.ForceInstallMode
    }

    $componentParameters = @{
        Name = $package.Name
        MsiPath = Join-Path (Join-Path $PSScriptRoot 'Files') $package.MsiPath
        ProductCode = $package.ProductCode
        InstallArgs = $package.InstallArgs
        UninstallArgs = $package.UninstallArgs
        Opt_Action = $componentAction
    }

    if ($package.Transform) {
        $componentParameters.Transform = Join-Path (Join-Path $PSScriptRoot 'Files') $package.Transform
    }

    Raynet_MSI @componentParameters
}

$result = Invoke-RaynetPackage `
    -Action $Action `
    -AppName $AppName `
    -AppVersion $AppVersion `
    -PackageRevision $PackageRevision `
    -Components (Get-RaynetComponents)

exit $result.ExitCode
