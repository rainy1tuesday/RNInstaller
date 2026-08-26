function Raynet_MSI {
<#
.SYNOPSIS
    Defines a Windows Installer MSI component.

.DESCRIPTION
    Installs or uninstalls an MSI package. The framework performs product-code detection and always supplies /qn /norestart for MSI install and uninstall operations.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER MsiPath
    Path to the MSI package. Relative paths are resolved against the package script directory.

.PARAMETER Transform
    Optional MST transform applied during MSI installation.

.PARAMETER InstallArgs
    Additional msiexec installation arguments/properties. The framework supplies /qn /norestart automatically.

.PARAMETER UninstallArgs
    Additional msiexec uninstall arguments/properties. The framework supplies /qn /norestart automatically.

.PARAMETER ProductCode
    MSI product code GUID used for installed-state detection and uninstall.

.PARAMETER Opt_Action
    Controls which package action executes this component. 'Default' follows the package Install/Uninstall action; 'Install' or 'Uninstall' overrides it for this component. Default: Default.

.PARAMETER Opt_Critical
    Controls failure handling. When true, a component failure stops package execution. When false, the failure is logged and the package continues. Default: $true.

.PARAMETER Opt_TimeoutSeconds
    Maximum component execution time in seconds where the implementation supports a timeout. A value of 0 means no explicit component timeout. Default: 0.

.PARAMETER Opt_SuccessExitCodes
    Exit codes considered successful by components that launch external installers/processes. Default: @(0,3010).

.PARAMETER Opt_RebootExitCodes
    Exit codes that mark the package as requiring a reboot. Default: @(3010,1641).

.PARAMETER Opt_Force
    Requests execution even when the component would otherwise consider the desired state already satisfied, where supported. Default: $false.

.PARAMETER Opt_Verify
    Enables post-action verification where supported. Default: $true.

.EXAMPLE
    Raynet_MSI -Name 'Install MyApp' -ProductCode '{11111111-2222-3333-4444-555555555555}' -MsiPath 'Files\MyApp.msi'

.EXAMPLE
    Raynet_MSI -Name 'Install transformed MyApp' -ProductCode '{11111111-2222-3333-4444-555555555555}' -MsiPath 'Files\MyApp.msi' -Transform 'Files\MyApp.mst'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_MSI -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$MsiPath,[Parameter(Mandatory=$false)][string]$Transform,[Parameter(Mandatory=$false)][string]$InstallArgs,[Parameter(Mandatory=$false)][string]$UninstallArgs,[Parameter(Mandatory=$false)][string]$ProductCode,
[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
$c=@{Type='MSI';Name=$Name;MsiPath=$MsiPath;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify};foreach($p in 'Transform','InstallArgs','UninstallArgs','ProductCode'){if($PSBoundParameters.ContainsKey($p)){$c[$p]=Get-Variable $p -ValueOnly}};Add-RaynetComponent $c
}

function Invoke-RaynetMSI {
    param([Parameter(Mandatory=$true)][hashtable]$Component,[Parameter(Mandatory=$true)][string]$LogRoot,[Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Action)
    $Logs=Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action; $log=$Logs.WrapperLog; $msilog=$Logs.MsiLog
    try {
        foreach($p in 'ProductCode'){if(-not $Component.ContainsKey($p)-or [string]::IsNullOrWhiteSpace($Component[$p])){throw "Component [$($Component.Name)] is missing property [$p]."}}
        $installed=Raynet_TestMSIInstalled $Component.ProductCode
        Write-RaynetInstallerLog $log "MSI action [$Action]. ProductCode=[$($Component.ProductCode)] InstalledBefore=[$installed]"
        if($Action -eq 'Install' -and $installed){Write-RaynetInstallerLog -LogFile $log -Message 'MSI already installed; skipping.' -Level SUCCESS;return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState:$true}
        if($Action -eq 'Uninstall' -and -not $installed){Write-RaynetInstallerLog -LogFile $log -Message 'MSI not installed; skipping.' -Level SUCCESS;return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState:$true}
        if($Action -eq 'Install'){
            if(-not $Component.ContainsKey('MsiPath')){throw "Component [$($Component.Name)] is missing property [MsiPath]."}
            $access=Test-RaynetPathAccess -Path $Component.MsiPath -Mode Read -LogFile $log -Label 'MSI source'; if(-not $access.Readable){throw "MSI is not readable [$($Component.MsiPath)]"}
            $args="/i `"$($Component.MsiPath)`" /qn /norestart"; if($Component.Transform){$args+=" TRANSFORMS=`"$($Component.Transform)`""}; if($Component.InstallArgs){$args+=" $($Component.InstallArgs)"}
        } else {$args="/x $($Component.ProductCode) /qn /norestart";if($Component.UninstallArgs){$args+=" $($Component.UninstallArgs)"}}
        $args+=" /L*v `"$msilog`""; Write-RaynetInstallerLog $log "msiexec.exe $args"
        $pr=Start-Process msiexec.exe -ArgumentList $args -Wait -PassThru -ErrorAction Stop
        Write-RaynetInstallerLog $log "msiexec ExitCode=[$($pr.ExitCode)]"
        $after=Raynet_TestMSIInstalled $Component.ProductCode
        $reboot=$pr.ExitCode -in 3010,1641
        if($Action -eq 'Install'){$success=($pr.ExitCode -eq 0 -or $reboot) -and $after}else{$success=($pr.ExitCode -in 0,1605 -or $reboot) -and -not $after}
        if(-not $success){throw "MSI action failed or post-action detection was incorrect. ExitCode=[$($pr.ExitCode)] InstalledAfter=[$after]"}
        Write-RaynetInstallerLog -LogFile $log -Message "MSI action completed. InstalledAfter=[$after] RebootRequired=[$reboot]" -Level SUCCESS
        return New-RaynetComponentResult $true $(if($reboot){3010}else{0}) -RebootRequired:$reboot
    } catch {Write-RaynetInstallerLog $log $_.Exception.Message ERROR;return New-RaynetComponentResult -Success $false -ExitCode 1 -Error $_.Exception.Message -ErrorMessage $_.Exception.ToString()}
}

function Raynet_TestMSIInstalled {
<#
.SYNOPSIS
    Tests whether an MSI product is installed.

.DESCRIPTION
    Checks the standard 64-bit and 32-bit Windows uninstall registry locations for the supplied MSI ProductCode. This helper is used by Raynet_MSI detection and verification.

.PARAMETER ProductCode
    MSI product code GUID to detect.

.EXAMPLE
    Raynet_TestMSIInstalled -ProductCode '{11111111-2222-3333-4444-555555555555}'

.OUTPUTS
    System.Boolean. True when the product code is detected; otherwise false.

.NOTES
    Raynet Installer Framework 0.4. Primarily an internal MSI detection helper, but currently exported by the module naming convention.
#>

    param(
        [string]$ProductCode
    )

    $Paths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )

    foreach ($Path in $Paths) {
        $Result = Get-ItemProperty $Path -ErrorAction SilentlyContinue |
        Where-Object {
            $_.PSChildName -eq $ProductCode
        }

        if ($Result) {
            return $true
        }
    }

    return $false
}
