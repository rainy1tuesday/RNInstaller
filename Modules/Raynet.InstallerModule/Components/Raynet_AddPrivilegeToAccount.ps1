function Raynet_AddPrivilegeToAccount {
<#
.SYNOPSIS
    Defines a Windows user-right assignment component.

.DESCRIPTION
    Assigns a Windows user right/privilege to an account using the framework component model. The current implementation treats uninstall as a no-op and logs that privilege removal is not implemented.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER AccountName
    Local or domain account that should receive the specified user right.

.PARAMETER Privilege
    Windows user-right name, for example SeServiceLogonRight.

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
    Raynet_AddPrivilegeToAccount -Name 'Grant service logon' -AccountName 'CONTOSO\svc_app' -Privilege 'SeServiceLogonRight'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_AddPrivilegeToAccount -Full for complete native PowerShell help.
#>
[CmdletBinding()]param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$AccountName,[Parameter(Mandatory=$true)][string]$Privilege,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true);Add-RaynetComponent @{Type='AddPrivilegeToAccount';Name=$Name;AccountName=$AccountName;Privilege=$Privilege;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}

function Invoke-RaynetAddPrivilegeToAccount {
    param(
        [hashtable]$Component,
        [string]$LogRoot,
        [string]$Action
    )

    $Logs = Get-RaynetComponentLogs `
        -Component $Component `
        -LogRoot $LogRoot `
        -Action $Action

    $WrapperLog = $Logs.WrapperLog

    try {

        if ($Action -ieq "Uninstall") {

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Level "WARNING" `
                -Message "Privilege removal not implemented. Skipping."

            return @{
                Success  = $true
                ExitCode = 0
                Skipped  = $true
            }
        }

        if (-not $Component.ContainsKey("AccountName")) {
            throw "Component [$($Component.Name)] is missing property [AccountName]."
        }

        if (-not $Component.ContainsKey("Privilege")) {
            throw "Component [$($Component.Name)] is missing property [Privilege]."
        }

        $AccountName = $Component.AccountName
        $Privilege = $Component.Privilege

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Granting privilege [$Privilege] to account [$AccountName]"

        #
        # Resolve SID
        #

        $Sid = (
            New-Object System.Security.Principal.NTAccount($AccountName)
        ).Translate(
            [System.Security.Principal.SecurityIdentifier]
        ).Value

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Resolved SID [$Sid]"

        #
        # Export policy
        #

        $TempInf = Join-Path $env:TEMP "Raynet_UserRights.inf"

        secedit.exe `
            /export `
            /cfg $TempInf | Out-Null

        $Content = Get-Content $TempInf

        $ExistingLine = $Content |
        Where-Object { $_ -match "^$Privilege\s*=" }

        if ($ExistingLine) {

            if ($ExistingLine -match [regex]::Escape($Sid)) {

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Level "SUCCESS" `
                    -Message "Privilege already assigned."

                return @{
                    Success  = $true
                    ExitCode = 0
                }
            }

            $NewLine = "$ExistingLine,*$Sid"

            $Content = $Content -replace `
                [string]::Escape($ExistingLine),
            [string]::Escape($NewLine)
        }
        else {

            $Content += "$Privilege = *$Sid"
        }

        Set-Content `
            -Path $TempInf `
            -Value $Content `
            -Encoding Unicode

        #
        # Apply policy
        #

        secedit.exe `
            /configure `
            /db "$env:TEMP\Raynet_UserRights.sdb" `
            /cfg $TempInf `
            /areas USER_RIGHTS | Out-Null

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Level "SUCCESS" `
            -Message "Privilege assigned successfully."

        return @{
            Success  = $true
            ExitCode = 0
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
