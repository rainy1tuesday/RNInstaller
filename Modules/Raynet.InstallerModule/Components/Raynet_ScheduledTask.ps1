function Raynet_ScheduledTask {
<#
.SYNOPSIS
    Defines a Windows Scheduled Task component.

.DESCRIPTION
    Creates, executes/configures, detects or removes a scheduled task according to the package action and task options. Supports temporary immediate tasks such as restarting Explorer in the logged-on user context.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER TaskName
    Windows Scheduled Task name.

.PARAMETER Execute
    Executable or command invoked by the scheduled task.

.PARAMETER TriggerType
    Scheduled task trigger type supported by the implementation, for example Immediate or Hourly.

.PARAMETER Opt_Arguments
    Additional command-line arguments or task arguments, depending on component.

.PARAMETER Opt_Description
    Optional task description.

.PARAMETER Opt_Interval
    Trigger repetition interval where applicable. Default: 1.

.PARAMETER Opt_StartTime
    Start time used by applicable trigger types. Default: 00:00.

.PARAMETER Opt_DaysOfWeek
    Optional day-of-week specification for applicable triggers.

.PARAMETER Opt_Enabled
    Create/leave the task enabled. Default: $true.

.PARAMETER Opt_RemoveAfterRun
    Remove a temporary/one-shot task after execution. Default: $false.

.PARAMETER Opt_ReplaceExisting
    Replace an existing task with the same name. Default: $true.

.PARAMETER Opt_RunAs
    Task run context/account. Default: SYSTEM.

.PARAMETER Opt_RunLevel
    Task run level. Default: Highest.

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
    Raynet_ScheduledTask -Name 'Restart Explorer' -TaskName 'Raynet_RestartExplorer' -Execute 'explorer.exe' -TriggerType Immediate -Opt_RunAs LoggedOnUser -Opt_RemoveAfterRun $true

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_ScheduledTask -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$TaskName,[Parameter(Mandatory=$true)][string]$Execute,[Parameter(Mandatory=$true)][string]$TriggerType,
[Parameter(Mandatory=$false)][string]$Opt_Arguments,[Parameter(Mandatory=$false)][string]$Opt_Description,[Parameter(Mandatory=$false)][int]$Opt_Interval=1,[Parameter(Mandatory=$false)][string]$Opt_StartTime='00:00',[Parameter(Mandatory=$false)][string]$Opt_DaysOfWeek,[Parameter(Mandatory=$false)][bool]$Opt_Enabled=$true,[Parameter(Mandatory=$false)][bool]$Opt_RemoveAfterRun=$false,[Parameter(Mandatory=$false)][bool]$Opt_ReplaceExisting=$true,[Parameter(Mandatory=$false)][string]$Opt_RunAs='SYSTEM',[Parameter(Mandatory=$false)][string]$Opt_RunLevel='Highest',[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
$c=@{Type='ScheduledTask';Name=$Name;TaskName=$TaskName;Execute=$Execute;TriggerType=$TriggerType;Opt_Arguments=$Opt_Arguments;Opt_Description=$Opt_Description;Opt_Interval=$Opt_Interval;Opt_StartTime=$Opt_StartTime;Opt_DaysOfWeek=$Opt_DaysOfWeek;Opt_Enabled=$Opt_Enabled;Opt_RemoveAfterRun=$Opt_RemoveAfterRun;Opt_ReplaceExisting=$Opt_ReplaceExisting;Opt_RunAs=$Opt_RunAs;Opt_RunLevel=$Opt_RunLevel;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify};Add-RaynetComponent $c
}

function Invoke-RaynetScheduledTask {
    param(
        [Parameter(Mandatory)]
        [hashtable]$Component,

        [Parameter(Mandatory)]
        [string]$LogRoot,

        [Parameter(Mandatory)]
        [ValidateSet('Install', 'Uninstall', 'Detect')]
        [string]$Action
    )

    $Logs = Get-RaynetComponentLogs `
        -Component $Component `
        -LogRoot $LogRoot `
        -Action $Action

    $WrapperLog = $Logs.WrapperLog

    try {

        $TaskName = $Component.TaskName

        $StringType = [String]
        if ($StringType::IsNullOrWhiteSpace($TaskName)) {

            throw "Component [$($Component.Name)] is missing property [TaskName]"
        }

        switch ($Action) {

            'Detect' {

                if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Level "SUCCESS" `
                        -Message "Scheduled task detected [$TaskName]"

                    return @{
                        Success  = $true
                        ExitCode = 0
                    }
                }

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Level "WARNING" `
                    -Message "Scheduled task not found [$TaskName]"

                return @{
                    Success  = $false
                    ExitCode = 1
                }
            }

            'Uninstall' {

                if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {

                    Unregister-ScheduledTask `
                        -TaskName $TaskName `
                        -Confirm:$false

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Message "Scheduled task removed [$TaskName]"
                }
                else {

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Level "WARNING" `
                        -Message "Scheduled task not present [$TaskName]"
                }

                return @{
                    Success  = $true
                    ExitCode = 0
                }
            }

            'Install' {

                $Execute = $Component.Execute
                $TriggerType = $Component.TriggerType

                $Arguments = if ($Component.ContainsKey('Opt_Arguments')) { $Component.Opt_Arguments } else { '' }
                $Description = if ($Component.ContainsKey('Opt_Description')) { $Component.Opt_Description } else { '' }
                $Interval = if ($Component.ContainsKey('Opt_Interval')) { [int]$Component.Opt_Interval } else { 1 }
                $StartTime = if ($Component.ContainsKey('Opt_StartTime')) { $Component.Opt_StartTime } else { '00:00' }
                $DaysOfWeek = if ($Component.ContainsKey('Opt_DaysOfWeek')) { $Component.Opt_DaysOfWeek } else { @('Monday') }
                $RunAs = if ($Component.ContainsKey('Opt_RunAs')) { $Component.Opt_RunAs } else { 'SYSTEM' }
                $RunLevel = if ($Component.ContainsKey('Opt_RunLevel')) { $Component.Opt_RunLevel } else { 'Highest' }
                $Enabled = if ($Component.ContainsKey('Opt_Enabled')) { [bool]$Component.Opt_Enabled } else { $true }
                $ReplaceExisting = if ($Component.ContainsKey('Opt_ReplaceExisting')) { [bool]$Component.Opt_ReplaceExisting } else { $true }
                $RemoveAfterRun = if ($Component.ContainsKey('Opt_RemoveAfterRun')) {
                    [bool]$Component.Opt_RemoveAfterRun
                }
                else {
                    $false
                }

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Message "Creating task [$TaskName]"

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Message "Execute [$Execute]"

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Message "TriggerType [$TriggerType]"

                $ExistingTask = Get-ScheduledTask `
                    -TaskName $TaskName `
                    -ErrorAction SilentlyContinue

                if ($ExistingTask) {

                    if ($ReplaceExisting) {

                        Write-RaynetInstallerLog `
                            -LogFile $WrapperLog `
                            -Message "Existing task found. Replacing."

                        Unregister-ScheduledTask `
                            -TaskName $TaskName `
                            -Confirm:$false
                    }
                    else {

                        throw "Scheduled task already exists [$TaskName]"
                    }
                }
                $StringType = [String]
                if ($StringType::IsNullOrWhiteSpace($Arguments)) {

                    $TaskAction = New-ScheduledTaskAction `
                        -Execute $Execute
                }
                else {

                    $TaskAction = New-ScheduledTaskAction `
                        -Execute $Execute `
                        -Argument $Arguments
                }

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Message "Arguments [$Arguments]"


                switch ($TriggerType) {

                    'Hourly' {

                        $Trigger = New-ScheduledTaskTrigger `
                            -Once `
                            -At (Get-Date)

                        $Trigger.Repetition.Interval = "PT${Interval}H"
                        $Trigger.Repetition.Duration = "P9999D"
                    }

                    'Daily' {

                        $Trigger = New-ScheduledTaskTrigger `
                            -Daily `
                            -DaysInterval $Interval `
                            -At $StartTime
                    }

                    'Weekly' {

                        $Trigger = New-ScheduledTaskTrigger `
                            -Weekly `
                            -WeeksInterval $Interval `
                            -DaysOfWeek $DaysOfWeek `
                            -At $StartTime
                    }

                    'AtStartup' {

                        $Trigger = New-ScheduledTaskTrigger `
                            -AtStartup
                    }

                    'AtLogon' {

                        $Trigger = New-ScheduledTaskTrigger `
                            -AtLogOn
                    }
                    'Immediate' {

                        $Trigger = New-ScheduledTaskTrigger `
                            -Once `
                            -At ((Get-Date).AddMinutes(5))
                    }

                    default {

                        throw "Unsupported TriggerType [$TriggerType]"
                    }
                }

                $Settings = New-ScheduledTaskSettingsSet

                switch ($RunAs) {

                    'SYSTEM' {

                        $Principal = New-ScheduledTaskPrincipal `
                            -UserId 'SYSTEM' `
                            -LogonType ServiceAccount `
                            -RunLevel $RunLevel

                        $Task = New-ScheduledTask `
                            -Action $TaskAction `
                            -Trigger $Trigger `
                            -Principal $Principal `
                            -Settings $Settings

                        if ($Description) {
                            $Task.Description = $Description
                        }

                        Register-ScheduledTask `
                            -TaskName $TaskName `
                            -InputObject $Task `
                            -Force | Out-Null
                    }

                    'LoggedOnUser' {

                        $LoggedOnUser = (
                            Get-CimInstance Win32_ComputerSystem
                        ).UserName

                        if ([string]::IsNullOrWhiteSpace($LoggedOnUser)) {
                            throw "No logged-on user found."
                        }

                        Write-RaynetInstallerLog `
                            -LogFile $WrapperLog `
                            -Message "LoggedOnUser [$LoggedOnUser]"

                        if ([string]::IsNullOrWhiteSpace($Description)) {

                            Register-ScheduledTask `
                                -TaskName $TaskName `
                                -Action $TaskAction `
                                -Trigger $Trigger `
                                -User $LoggedOnUser `
                                -RunLevel $RunLevel `
                                -Force | Out-Null
                        }
                        else {

                            Register-ScheduledTask `
                                -TaskName $TaskName `
                                -Action $TaskAction `
                                -Trigger $Trigger `
                                -Description $Description `
                                -User $LoggedOnUser `
                                -RunLevel $RunLevel `
                                -Force | Out-Null
                        }

                        if ($TriggerType -eq 'Immediate') {

                            Start-ScheduledTask `
                                -TaskName $TaskName

                            Write-RaynetInstallerLog `
                                -LogFile $WrapperLog `
                                -Message "Immediate task started."

                            if ($RemoveAfterRun) {

                                Start-Sleep -Seconds 10

                                Unregister-ScheduledTask `
                                    -TaskName $TaskName `
                                    -Confirm:$false `
                                    -ErrorAction SilentlyContinue

                                Write-RaynetInstallerLog `
                                    -LogFile $WrapperLog `
                                    -Message "Temporary task removed [$TaskName]"
                            }
                        }
                    
                    }

                    default {

                        throw "Unsupported Opt_RunAs [$RunAs]"
                    }
                }

                if (-not $Enabled) {

                    Disable-ScheduledTask `
                        -TaskName $TaskName | Out-Null
                }

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Level "SUCCESS" `
                    -Message "Scheduled task created [$TaskName]"

                return @{
                    Success  = $true
                    ExitCode = 0
                }
            }
        }
    }
    catch {

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Level "ERROR" `
            -Message $_.Exception.Message

        return @{
            Success      = $false
            ExitCode     = 1
            Error        = $_.Exception.Message
            ErrorMessage = $_.Exception.Message
        }
    }
}
