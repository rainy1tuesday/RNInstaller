function Raynet_ConfigureService {
<#
.SYNOPSIS
    Defines a Windows service configuration component.

.DESCRIPTION
    Changes service configuration such as startup type and optional logon account without requiring a start/stop ServiceAction. Use Raynet_Service for operational start, stop, or restart actions.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER ServiceName
    Windows service name, not the display name.

.PARAMETER Opt_Configure_StartType
    Optional service startup type. Supported values: Automatic, AutomaticDelayed, Manual, Disabled.

.PARAMETER Opt_Configure_AccountName
    Optional service logon account.

.PARAMETER Opt_Configure_Password
    Optional password for the configured service account.

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
    Raynet_ConfigureService -Name 'Disable legacy service' -ServiceName 'LegacySvc' -Opt_Configure_StartType Disabled -Opt_Critical $false

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_ConfigureService -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$ServiceName,[Parameter(Mandatory=$false)][ValidateSet('Automatic','AutomaticDelayed','Manual','Disabled')][string]$Opt_Configure_StartType,
[Parameter(Mandatory=$false)][string]$Opt_Configure_AccountName,[Parameter(Mandatory=$false)][string]$Opt_Configure_Password,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
$c=@{Type='ConfigureService';Name=$Name;ServiceName=$ServiceName;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}; if($PSBoundParameters.ContainsKey('Opt_Configure_StartType')){$c.Opt_Configure_StartType=$Opt_Configure_StartType};if($PSBoundParameters.ContainsKey('Opt_Configure_AccountName')){$c.Opt_Configure_AccountName=$Opt_Configure_AccountName};if($PSBoundParameters.ContainsKey('Opt_Configure_Password')){$c.Opt_Configure_Password=$Opt_Configure_Password};Add-RaynetComponent $c
}

function Invoke-RaynetConfigureService {
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )
    $log=(Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action).WrapperLog
    try {
        if (-not $Component.ServiceName) { throw 'ServiceName is required.' }
        $name=[string]$Component.ServiceName
        $svc=Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) {
            $summary="Service [$name] is not present, therefore no configuration change was necessary."
            Write-RaynetInstallerLog -LogFile $log -Message $summary -Level INFO
            return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState $true -Data @{Summary=$summary}
        }
        $startType=$Component.Opt_Configure_StartType; $account=$Component.Opt_Configure_AccountName; $password=$Component.Opt_Configure_Password
        if (-not $startType -and -not $account) { throw 'ConfigureService requires Opt_Configure_StartType and/or Opt_Configure_AccountName.' }
        if ($startType) {
            Write-RaynetInstallerLog -LogFile $log -Message "Setting startup type for service [$name] to [$startType]." -Level INFO
            switch ($startType) {
                'Automatic' { Set-Service -Name $name -StartupType Automatic -ErrorAction Stop }
                'AutomaticDelayed' { Set-Service -Name $name -StartupType Automatic -ErrorAction Stop; sc.exe config $name start= delayed-auto | Out-Null }
                'Manual' { Set-Service -Name $name -StartupType Manual -ErrorAction Stop }
                'Disabled' { Set-Service -Name $name -StartupType Disabled -ErrorAction Stop }
                default { throw "Unsupported startup type [$startType]." }
            }
        }
        if ($account) {
            Write-RaynetInstallerLog -LogFile $log -Message "Changing service account for [$name] to [$account]." -Level INFO
            $obj=Get-CimInstance Win32_Service -Filter "Name='$name'" -ErrorAction Stop
            $res=Invoke-CimMethod -InputObject $obj -MethodName Change -Arguments @{StartName=$account;StartPassword=$password}
            if ($res.ReturnValue -ne 0) { throw "Changing service account failed. ReturnValue [$($res.ReturnValue)]." }
        }
        $summary="Service [$name] configuration completed successfully."
        Write-RaynetInstallerLog -LogFile $log -Message $summary -Level SUCCESS
        return New-RaynetComponentResult -Success $true -ExitCode 0 -Data @{Summary=$summary}
    } catch {
        $summary="Service [$($Component.ServiceName)] could not be configured. Reason: $($_.Exception.Message)"
        Write-RaynetInstallerLog -LogFile $log -Message $summary -Level ERROR
        return New-RaynetComponentResult -Success $false -ExitCode 1 -Error $_.Exception.Message -ErrorMessage $_.Exception.ToString() -Data @{Summary=$summary}
    }
}
