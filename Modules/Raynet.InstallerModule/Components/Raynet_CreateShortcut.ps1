function Raynet_CreateShortcut {
<#
.SYNOPSIS
    Defines a Windows shortcut component.

.DESCRIPTION
    Creates or removes a shortcut using the requested location, scope, target and optional shortcut metadata.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER Target
    Target path or executable for the shortcut.

.PARAMETER ShortcutName
    Name of the shortcut file.

.PARAMETER Location
    Base shortcut location interpreted by the component, such as Desktop or StartMenu.

.PARAMETER Scope
    Shortcut scope. Default: AllUsers.

.PARAMETER SubFolder
    Optional subfolder below the selected shortcut location.

.PARAMETER Arguments
    Optional command-line arguments passed to the shortcut target or executable installer, depending on component.

.PARAMETER Description
    Optional shortcut description.

.PARAMETER IconLocation
    Optional icon path/location for a shortcut.

.PARAMETER WorkingDirectory
    Optional working directory for the shortcut target.

.PARAMETER ShortcutType
    Shortcut type handled by the component, such as LNK where supported.

.PARAMETER Overwrite
    Replace an existing shortcut with the same name. Default: $true.

.PARAMETER CreateFolder
    Create the target shortcut folder when it does not exist. Default: $true.

.PARAMETER RunAsAdmin
    Configure the shortcut to request elevation where supported. Default: $false.

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
    Raynet_CreateShortcut -Name 'Create MyApp shortcut' -Target 'C:\Program Files\MyApp\MyApp.exe' -ShortcutName 'MyApp' -Location 'Desktop'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_CreateShortcut -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$Target,[Parameter(Mandatory=$true)][string]$ShortcutName,[Parameter(Mandatory=$false)][string]$Location,[Parameter(Mandatory=$false)][string]$Scope='AllUsers',[Parameter(Mandatory=$false)][string]$SubFolder,[Parameter(Mandatory=$false)][string]$Arguments,[Parameter(Mandatory=$false)][string]$Description,[Parameter(Mandatory=$false)][string]$IconLocation,[Parameter(Mandatory=$false)][string]$WorkingDirectory,[Parameter(Mandatory=$false)][string]$ShortcutType,[Parameter(Mandatory=$false)][bool]$Overwrite=$true,[Parameter(Mandatory=$false)][bool]$CreateFolder=$true,[Parameter(Mandatory=$false)][bool]$RunAsAdmin=$false,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
$c=@{Type='CreateShortcut';Name=$Name;Target=$Target;ShortcutName=$ShortcutName;Location=$Location;Scope=$Scope;SubFolder=$SubFolder;Arguments=$Arguments;Description=$Description;IconLocation=$IconLocation;WorkingDirectory=$WorkingDirectory;ShortcutType=$ShortcutType;Overwrite=$Overwrite;CreateFolder=$CreateFolder;RunAsAdmin=$RunAsAdmin;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify};Add-RaynetComponent $c
}

function Invoke-RaynetCreateShortcut {
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

        #
        # Defaults
        #

        if (-not $Component.ContainsKey("Scope")) {
            $Component.Scope = "AllUsers"
        }

        if (-not $Component.ContainsKey("Overwrite")) {
            $Component.Overwrite = $true
        }

        if (-not $Component.ContainsKey("CreateFolder")) {
            $Component.CreateFolder = $true
        }

        #
        # Validation
        #

        foreach ($Property in @(
                "ShortcutType",
                "Location",
                "ShortcutName"
            )) {

            if (-not $Component.ContainsKey($Property)) {
                throw "Missing property [$Property]"
            }
        }

        #
        # Resolve base folder
        #

        switch ($Component.Location.ToUpper()) {

            "DESKTOP" {

                if ($Component.Scope -eq "AllUsers") {

                    $ShortcutFolder =
                    [Environment]::GetFolderPath(
                        "CommonDesktopDirectory"
                    )
                }
                else {

                    $ShortcutFolder =
                    [Environment]::GetFolderPath(
                        "Desktop"
                    )
                }
            }

            "STARTMENU" {

                if ($Component.Scope -eq "AllUsers") {

                    $ShortcutFolder =
                    "$env:ProgramData\Microsoft\Windows\Start Menu\Programs"
                }
                else {

                    $ShortcutFolder =
                    "$env:APPDATA\Microsoft\Windows\Start Menu\Programs"
                }
            }

            default {

                throw "Unsupported Location [$($Component.Location)]"
            }
        }

        #
        # SubFolder
        #

        if (
            $Component.ContainsKey("SubFolder") -and
            -not ([string]::IsNullOrWhiteSpace($Component.SubFolder))
        ) {

            $ShortcutFolder = Join-Path `
                $ShortcutFolder `
                $Component.SubFolder

            if ($Component.CreateFolder) {

                New-Item `
                    -Path $ShortcutFolder `
                    -ItemType Directory `
                    -Force `
                    -ErrorAction Stop | Out-Null

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Message "Verified folder [$ShortcutFolder]"
            }
            elseif (-not (Test-Path $ShortcutFolder)) {

                throw "Folder does not exist [$ShortcutFolder]"
            }
        }

        #
        # Extension
        #

        if ($Component.ShortcutType.ToUpper() -eq "URL") {

            $ShortcutFile = Join-Path `
                $ShortcutFolder `
                "$($Component.ShortcutName).url"
        }
        else {

            $ShortcutFile = Join-Path `
                $ShortcutFolder `
                "$($Component.ShortcutName).lnk"
        }

        #
        # Uninstall
        #

        if ($Action -ieq "Uninstall") {

            if (Test-Path $ShortcutFile) {

                Remove-Item `
                    -Path $ShortcutFile `
                    -Force `
                    -ErrorAction Stop

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Message "Removed shortcut [$ShortcutFile]"
            }

            return @{
                Success  = $true
                ExitCode = 0
            }
        }

        #
        # Overwrite
        #

        if (Test-Path $ShortcutFile) {

            if ($Component.Overwrite) {

                Remove-Item `
                    -Path $ShortcutFile `
                    -Force `
                    -ErrorAction Stop
            }
            else {

                throw "Shortcut already exists [$ShortcutFile]"
            }
        }

        #
        # Create shortcut
        #

        switch ($Component.ShortcutType.ToUpper()) {

            "LNK" {

                if (-not (Test-Path $Component.Target)) {
                    throw "Target not found [$($Component.Target)]"
                }

                $Shell = New-Object -ComObject WScript.Shell

                $Shortcut = $Shell.CreateShortcut(
                    $ShortcutFile
                )

                $Shortcut.TargetPath = $Component.Target

                if ($Component.ContainsKey("Arguments")) {
                    $Shortcut.Arguments = $Component.Arguments
                }

                if ($Component.ContainsKey("Description")) {
                    $Shortcut.Description = $Component.Description
                }

                if ($Component.ContainsKey("IconLocation")) {
                    $Shortcut.IconLocation = $Component.IconLocation
                }

                if ($Component.ContainsKey("WorkingDirectory")) {
                    $Shortcut.WorkingDirectory = $Component.WorkingDirectory
                }

                $Shortcut.Save()

                if (
                    $Component.ContainsKey("RunAsAdmin") -and
                    $Component.RunAsAdmin
                ) {

                    Set-RaynetShortcutRunAsAdministrator `
                        -ShortcutPath $ShortcutFile
                }
            }

            "URL" {

                @"
[InternetShortcut]
URL=$($Component.Target)
"@ | Set-Content `
                    -Path $ShortcutFile `
                    -Encoding ASCII
            }

            "APP" {

                $Shell = New-Object -ComObject WScript.Shell

                $Shortcut = $Shell.CreateShortcut(
                    $ShortcutFile
                )

                $Shortcut.TargetPath = "explorer.exe"

                $Shortcut.Arguments =
                "shell:AppsFolder\$($Component.Target)"

                $Shortcut.Save()
            }

            default {

                throw "Unsupported ShortcutType [$($Component.ShortcutType)]"
            }
        }

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Level "SUCCESS" `
            -Message "Shortcut created [$ShortcutFile]"

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
