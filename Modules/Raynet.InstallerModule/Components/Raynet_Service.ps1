function Raynet_Service {
<#
.SYNOPSIS
    Defines a Windows service action component.

.DESCRIPTION
    Performs operational start, stop or restart actions on a Windows service. Use Raynet_ConfigureService for service configuration such as startup type.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER ServiceName
    Windows service name, not the display name.

.PARAMETER ServiceAction
    Operational service action: start, stop, or restart.

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
    Raynet_Service -Name 'Stop MyApp service' -ServiceName 'MyAppSvc' -ServiceAction stop -Opt_Critical $false

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_Service -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$ServiceName,[Parameter(Mandatory=$true)][ValidateSet('start','stop','restart')][string]$ServiceAction,
[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
Add-RaynetComponent -Component @{Type='Service';Name=$Name;ServiceName=$ServiceName;ServiceAction=$ServiceAction;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}

function Invoke-RaynetService {
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )
    $log = (Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action).WrapperLog
    try {
        foreach ($p in 'ServiceName','ServiceAction') { if (-not $Component.ContainsKey($p)) { throw "Missing property [$p]." } }
        $name=[string]$Component.ServiceName; $requested=[string]$Component.ServiceAction
        Write-RaynetInstallerLog -LogFile $log -Message "Requested service action: [$requested] service [$name]." -Level INFO
        $svc=Get-Service -Name $name -ErrorAction SilentlyContinue
        if (-not $svc) {
            $summary = if ($requested.ToLower() -eq 'stop') { "Service [$name] is not present, therefore it was not necessary to stop it; desired state is already satisfied." } else { "Service [$name] is not present, so action [$requested] cannot be performed." }
            if ($requested.ToLower() -eq 'stop') {
                Write-RaynetInstallerLog -LogFile $log -Message $summary -Level INFO
                return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState $true -Data @{Summary=$summary}
            }
            throw $summary
        }
        Write-RaynetInstallerLog -LogFile $log -Message "Current service status: [$($svc.Status)]." -Level INFO
        switch ($requested.ToLower()) {
            'stop' {
                if ($svc.Status -eq 'Stopped') { $summary="Service [$name] is already stopped; no action was necessary."; return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState $true -Data @{Summary=$summary} }
                Stop-Service -Name $name -Force -ErrorAction Stop
                $svc.WaitForStatus('Stopped',[TimeSpan]::FromSeconds($(if($Component.Opt_TimeoutSeconds -gt 0){$Component.Opt_TimeoutSeconds}else{120})))
                $summary="Service [$name] was stopped successfully."
            }
            'start' {
                if ($svc.Status -eq 'Running') { $summary="Service [$name] is already running; no action was necessary."; return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState $true -Data @{Summary=$summary} }
                Start-Service -Name $name -ErrorAction Stop; $summary="Service [$name] was started successfully."
            }
            'restart' { Restart-Service -Name $name -Force -ErrorAction Stop; $summary="Service [$name] was restarted successfully." }
            default { throw "Unsupported ServiceAction [$requested]." }
        }
        Write-RaynetInstallerLog -LogFile $log -Message $summary -Level SUCCESS
        return New-RaynetComponentResult -Success $true -ExitCode 0 -Data @{Summary=$summary}
    } catch {
        $summary="Service action failed for [$($Component.ServiceName)]. Reason: $($_.Exception.Message)"
        Write-RaynetInstallerLog -LogFile $log -Message $summary -Level ERROR
        return New-RaynetComponentResult -Success $false -ExitCode 1 -Error $_.Exception.Message -ErrorMessage $_.Exception.ToString() -Data @{Summary=$summary}
    }
}
