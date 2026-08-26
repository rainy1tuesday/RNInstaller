function Raynet_Process {
<#
.SYNOPSIS
    Defines a process termination component.

.DESCRIPTION
    Ensures that all matching process instances are stopped. If the process is not running, the component reports the desired state as already satisfied.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER ProcessName
    Process executable/name to stop. The extension may be supplied; the implementation normalizes it.

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
    Raynet_Process -Name 'Stop MyApp' -ProcessName 'MyApp.exe' -Opt_Critical $false

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_Process -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$ProcessName,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
Add-RaynetComponent -Component @{Type='Process';Name=$Name;ProcessName=$ProcessName;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}

function Invoke-RaynetProcess {
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )
    $log=(Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action).WrapperLog
    try {
        $name=[System.IO.Path]::GetFileNameWithoutExtension([string]$Component.ProcessName)
        $processes=@(Get-Process -Name $name -ErrorAction SilentlyContinue)
        if(-not $processes.Count){
            $summary="Process [$name] is not running; no action was necessary."
            Write-RaynetInstallerLog -LogFile $log -Message $summary -Level INFO
            return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState $true -Data @{Summary=$summary}
        }
        Write-RaynetInstallerLog -LogFile $log -Message "Found [$($processes.Count)] instance(s) of process [$name]; stopping them." -Level INFO
        foreach($proc in $processes){Stop-Process -Id $proc.Id -Force -ErrorAction Stop;Write-RaynetInstallerLog -LogFile $log -Message "Stopped process [$name], PID [$($proc.Id)]." -Level INFO}
        $summary="Process [$name] was stopped successfully."
        return New-RaynetComponentResult -Success $true -ExitCode 0 -Data @{Summary=$summary}
    } catch {
        $summary="Process [$($Component.ProcessName)] could not be stopped. Reason: $($_.Exception.Message)"
        Write-RaynetInstallerLog -LogFile $log -Message $summary -Level ERROR
        return New-RaynetComponentResult -Success $false -ExitCode 1 -Error $_.Exception.Message -ErrorMessage $_.Exception.ToString() -Data @{Summary=$summary}
    }
}
