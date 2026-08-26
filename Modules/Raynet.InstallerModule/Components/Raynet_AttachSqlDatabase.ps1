function Raynet_AttachSqlDatabase {
<#
.SYNOPSIS
    Defines a SQL database attach component.

.DESCRIPTION
    Runs the framework SQL database attach operation against a specified SQL Server. The current component is install-oriented; uninstall is skipped by the implementation.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER SqlFile
    SQL script/file used by the database attach implementation.

.PARAMETER SqlServer
    SQL Server instance to which the database operation is directed.

.PARAMETER SqlUser
    Optional SQL authentication user. If omitted, the implementation uses its default authentication behavior.

.PARAMETER SqlPassword
    Optional password associated with SqlUser. Treat as sensitive package data.

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
    Raynet_AttachSqlDatabase -Name 'Attach application database' -SqlFile 'Files\Database.sql' -SqlServer '.\SQLEXPRESS'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_AttachSqlDatabase -Full for complete native PowerShell help.
#>
[CmdletBinding()]param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$SqlFile,[Parameter(Mandatory=$true)][string]$SqlServer,[Parameter(Mandatory=$false)][string]$SqlUser,[Parameter(Mandatory=$false)][string]$SqlPassword,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true);Add-RaynetComponent @{Type='AttachSqlDatabase';Name=$Name;SqlFile=$SqlFile;SqlServer=$SqlServer;SqlUser=$SqlUser;SqlPassword=$SqlPassword;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}

function Invoke-RaynetAttachSqlDatabase {
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
                -Message "Database attach is install-only. Skipping."

            return @{
                Success  = $true
                ExitCode = 0
                Skipped  = $true
            }
        }

        if (-not $Component.ContainsKey("SqlFile")) {
            throw "Component [$($Component.Name)] is missing property [SqlFile]."
        }

        if (-not (Test-Path $Component.SqlFile)) {
            throw "SQL file not found [$($Component.SqlFile)]"
        }

        #
        # Verify all files referenced in the SQL script exist
        #

        $SqlContent = Get-Content `
            -Path $Component.SqlFile `
            -Raw

        $Matches = [regex]::Matches(
            $SqlContent,
            "FILENAME\s*=\s*N'([^']+)'"
        )

        foreach ($Match in $Matches) {

            $DatabaseFile = $Match.Groups[1].Value

            Write-RaynetInstallerLog `
                -LogFile $WrapperLog `
                -Message "Checking database file [$DatabaseFile]"

            if (-not (Test-Path -LiteralPath $DatabaseFile)) {

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Level "WARNING" `
                    -Message "Database file not found [$DatabaseFile]. Skipping database attach."

                return @{
                    Success  = $true
                    ExitCode = 0
                    Skipped  = $true
                    Message  = "Database files not present."
                }
            }
        }


        $SqlCmdPath = Join-Path `
            ${env:ProgramFiles} `
            "Microsoft SQL Server\Client SDK\ODBC\170\Tools\Binn\sqlcmd.exe"

        if (-not (Test-Path $SqlCmdPath)) {

            $SqlCmdPath = (Get-Command sqlcmd.exe -ErrorAction SilentlyContinue).Path
        }

        if (-not $SqlCmdPath) {
            throw "sqlcmd.exe not found."
        }

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "SQL File: $($Component.SqlFile)"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "SQL Server: $($Component.SqlServer)"

        $Arguments = @(
            "-S"
            $Component.SqlServer
            "-U"
            $Component.SqlUser
            "-P"
            $Component.SqlPassword
            "-i"
            "`"$($Component.SqlFile)`""
        )

        $Process = Start-Process `
            -FilePath $SqlCmdPath `
            -ArgumentList $Arguments `
            -Wait `
            -PassThru `
            -NoNewWindow

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "sqlcmd ExitCode [$($Process.ExitCode)]"

        if ($Process.ExitCode -ne 0) {
            throw "sqlcmd returned ExitCode [$($Process.ExitCode)]"
        }

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
