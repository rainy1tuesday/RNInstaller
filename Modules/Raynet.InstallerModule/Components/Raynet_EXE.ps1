function Raynet_EXE {
<#
.SYNOPSIS
    Defines an executable installer/action component.

.DESCRIPTION
    Runs an executable for install and optionally a separate executable/arguments for uninstall, with common Raynet failure, timeout and verification controls.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER ExePath
    Executable used for the Install action. Relative package paths are resolved against the main script directory.

.PARAMETER Arguments
    Optional command-line arguments passed to the shortcut target or executable installer, depending on component.

.PARAMETER UninstallExePath
    Optional executable used for the Uninstall action.

.PARAMETER UninstallArguments
    Optional arguments used with UninstallExePath.

.PARAMETER DetectionPath
    Optional filesystem path used to verify the executable component state.

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
    Raynet_EXE -Name 'Install MyApp' -ExePath 'Files\setup.exe' -Arguments '/silent' -UninstallExePath 'C:\Program Files\MyApp\uninstall.exe' -UninstallArguments '/silent'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_EXE -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$ExePath,[Parameter(Mandatory=$false)][string]$Arguments,[Parameter(Mandatory=$false)][string]$UninstallExePath,[Parameter(Mandatory=$false)][string]$UninstallArguments,[Parameter(Mandatory=$false)][string]$DetectionPath,
[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
$c=@{Type='EXE';Name=$Name;ExePath=$ExePath;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify};foreach($p in 'Arguments','UninstallExePath','UninstallArguments','DetectionPath'){if($PSBoundParameters.ContainsKey($p)){$c[$p]=Get-Variable $p -ValueOnly}};Add-RaynetComponent $c
}

function Invoke-RaynetEXE {
    param(
        [hashtable]$Component,
        [string]$LogRoot,
        [string]$Action
    )

    
    #
    # Defaults
    #

    if (-not $Component.ContainsKey("SuccessCodes")) {
        $Component.SuccessCodes = @(0)
    }

    if (-not $Component.ContainsKey("RebootCodes")) {
        $Component.RebootCodes = @{ 
            3010 = "Restaart required"
            1641 = "Restart initatedby installer"
        }
    }

    if (-not $Component.ContainsKey("FailureCodes")) {
        $Component.FailureCodes = @{}
    }

    if (-not $Component.ContainsKey("TimeoutSeconds")) {
        $Component.TimeoutSeconds = 0
    }

    try {

        $Logs = Get-RaynetComponentLogs `
            -Component $Component `
            -LogRoot $LogRoot `
            -Action $Action

        $WrapperLog = $Logs.WrapperLog

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "ACTION RECEIVED: [$Action]"

        #
        # Resolve executable and arguments
        #

        if ($Action -ieq "Install") {

            if (
                -not $Component.ContainsKey("ExePath") -or
                [string]::IsNullOrWhiteSpace($Component.ExePath)
            ) {
                throw "Component [$($Component.Name)] is missing property [ExePath]."
            }

            $ExePath = $Component.ExePath

            if (
                $Component.ContainsKey("Arguments") -and
                -not [string]::IsNullOrWhiteSpace($Component.Arguments)
            ) {
                $Arguments = $Component.Arguments
            }
            else {
                $Arguments = ""
            }
        }
        else {

            if (
                -not $Component.ContainsKey("UninstallExePath") -or
                [string]::IsNullOrWhiteSpace($Component.UninstallExePath)
            ) {

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Level "WARNING" `
                    -Message "No UninstallExePath defined. Automatic uninstall not possible."

                return @{
                    Success  = $true
                    Skipped  = $true
                    ExitCode = 0
                }
            }

            $ExePath = $Component.UninstallExePath

            if (
                $Component.ContainsKey("UninstallArguments") -and
                -not [string]::IsNullOrWhiteSpace($Component.UninstallArguments)
            ) {
                $Arguments = $Component.UninstallArguments
            }
            else {
                $Arguments = ""
            }
        }
    

        #
        # DEBUG
        #

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Component.ExePath = [$($Component.ExePath)]"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Resolved ExePath = [$ExePath]"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "ExePath Type = [$($ExePath.GetType().FullName)]"

        #
        # Validate executable
        #

        if (-not (Test-Path -LiteralPath $ExePath)) {
            throw "Executable not found [$ExePath]"
        }

        #
        # Validate executable
        #

        # ([string]::IsNullOrWhiteSpace($Entry.Key))

        if ([string]::IsNullOrWhiteSpace($ExePath)) {
            throw "Executable path is empty."
        }

        if (-not (Test-Path -LiteralPath $ExePath)) {
            throw "Executable not found [$ExePath]"
        }

        $FileInfo = Get-Item `
            -LiteralPath $ExePath `
            -ErrorAction Stop

        #
        # Logging
        #

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "EXE execution started"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Action: $Action"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Executable: $ExePath"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Arguments: $Arguments"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "File size: $($FileInfo.Length) bytes"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "Last modified: $($FileInfo.LastWriteTime)"

        #
        # Start process
        #
        $StartProcessParams = @{
            FilePath    = $ExePath
            PassThru    = $true
            ErrorAction = 'Stop'
        }

        if (-not [string]::IsNullOrWhiteSpace($Arguments)) {
            $StartProcessParams.ArgumentList = $Arguments
        }

        $Process = Start-Process @StartProcessParams

        #
        # Wait logic
        #

        if ($Component.TimeoutSeconds -eq 0) {

            $Process.WaitForExit()
            $TimedOut = $false
        }
        else {

            $TimedOut = -not $Process.WaitForExit(
                $Component.TimeoutSeconds * 1000
            )
        }

        #
        # Timeout handling
        #

        if ($TimedOut) {

            try {
                Stop-Process `
                    -Id $Process.Id `
                    -Force `
                    -ErrorAction SilentlyContinue
            }
            catch {
            }

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Level "ERROR" `
                -Message "Process timed out after $($Component.TimeoutSeconds) seconds"

            return @{
                Success      = $false
                ExitCode     = 1
                Error        = "Timeout"
                ErrorMessage = "Process timed out."
            }
        }

        $ExitCode = $Process.ExitCode

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "ExitCode: $ExitCode"

        #
        # Optional detection validation
        #

        if (
            $Action -eq "Install" -and
            $Component.ContainsKey("DetectionPath")
        ) {

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Message "Verifying detection path [$($Component.DetectionPath)]"

            if (-not (Test-Path -LiteralPath $Component.DetectionPath)) {

                throw "Installation completed but detection path was not found [$($Component.DetectionPath)]"
            }

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Level "SUCCESS" `
                -Message "Detection path verified"
        }

        #
        # Success
        #

        if ($ExitCode -in $Component.SuccessCodes) {

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Level "SUCCESS" `
                -Message "Process completed successfully"

            return @{
                Success  = $true
                ExitCode = $ExitCode
            }
        }

        #
        # Reboot required
        #

        if ($ExitCode -in $Component.RebootCodes) {

            $RebootMessage = $Component.RebootCodes[$ExitCode]

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Level "SUCCESS" `
                -Message "Reboot required [$ExitCode] : $RebootMessage"

            return @{
                Success        = $true
                ExitCode       = 3010
                RebootRequired = $true
                Message        = $RebootMessage
            }
        }

        #
        # Explicit failure codes
        #

        if ($Component.FailureCodes.ContainsKey($ExitCode)) {

            $FailureMessage = $Component.FailureCodes[$ExitCode]

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Level "ERROR" `
                -Message "Known failure code [$ExitCode] : $FailureMessage"

            return @{
                Success      = $false
                ExitCode     = $ExitCode
                Error        = $FailureMessage
                ErrorMessage = $FailureMessage
            }
        }

        #
        # Unexpected code
        #

        throw "Unexpected ExitCode [$ExitCode]"
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
