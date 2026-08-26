<#
.SYNOPSIS
    Defines a directory-deletion component.

.DESCRIPTION
    Removes a directory and, optionally, all child files and directories.

    The operation is idempotent: if the target directory does not exist, the
    component succeeds because the requested state is already satisfied.

    Relative paths are resolved against the main package script directory.

.PARAMETER Name
    Human-readable component name used in logging.

.PARAMETER Path
    Directory to remove.

.PARAMETER Opt_Recurse
    Remove the directory together with all child files and subdirectories.
    Default: true.

.PARAMETER Opt_Force
    Use forced deletion semantics. This allows deletion of hidden, system, and
    read-only content where filesystem permissions permit it.
    Default: true.

.PARAMETER Opt_Verify
    Verify that the directory no longer exists after deletion.
    Default: true.

.PARAMETER Opt_Action
    Component action override:
    Default, Install, or Uninstall.
    Default: Default.

.PARAMETER Opt_Critical
    If true, failure stops package execution.
    Default: true.

.PARAMETER Opt_TimeoutSeconds
    Maximum deletion duration in seconds. 0 disables the explicit timeout check.
    Default: 0.

.EXAMPLE
    Raynet_DeleteDirectory `
        -Name "Remove old application directory" `
        -Path "C:\Program Files\OldApp"

.EXAMPLE
    Raynet_DeleteDirectory `
        -Name "Remove cached data" `
        -Path "C:\ProgramData\MyApp\Cache" `
        -Opt_Recurse $true `
        -Opt_Force $true `
        -Opt_Critical $false

.OUTPUTS
    Adds a Raynet component definition to the current package.

.NOTES
    Raynet Installer Framework 0.4.
#>
function Raynet_DeleteDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$Path,

        [bool]$Opt_Recurse = $true,
        [bool]$Opt_Force = $true,
        [bool]$Opt_Verify = $true,

        [ValidateSet('Default','Install','Uninstall')]
        [string]$Opt_Action = 'Default',

        [bool]$Opt_Critical = $true,

        [ValidateRange(0,2147483647)]
        [int]$Opt_TimeoutSeconds = 0
    )

    Add-RaynetComponent @{
        Type               = 'DeleteDirectory'
        Name               = $Name
        Path               = $Path
        Opt_Recurse        = $Opt_Recurse
        Opt_Force          = $Opt_Force
        Opt_Verify         = $Opt_Verify
        Opt_Action         = $Opt_Action
        Opt_Critical       = $Opt_Critical
        Opt_TimeoutSeconds = $Opt_TimeoutSeconds
    }
}

<#
.SYNOPSIS
    Executes a Raynet_DeleteDirectory component.

.DESCRIPTION
    Resolves the target path, removes the directory according to the component
    options, logs the result, and optionally verifies that the target is gone.

.PARAMETER Component
    Normalized component definition.

.PARAMETER LogRoot
    Detail-log directory for this component.

.PARAMETER Action
    Effective Install or Uninstall action.

.OUTPUTS
    Raynet component result object.

.NOTES
    Raynet Installer Framework 0.4.
#>
function Invoke-RaynetDeleteDirectory {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [hashtable]$Component,

        [Parameter(Mandatory)]
        [string]$LogRoot,

        [Parameter(Mandatory)]
        [ValidateSet('Install','Uninstall')]
        [string]$Action
    )

    $logs = Get-RaynetComponentLogs `
        -Component $Component `
        -LogRoot $LogRoot `
        -Action $Action

    $log = $logs.WrapperLog

    try {
        $targetPath = Resolve-RaynetPackagePath `
            -Path ([string]$Component.Path) `
            -PackageRoot $Component['_PackageRoot']

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "DeleteDirectory requested. Path=[$targetPath] Recurse=[$($Component.Recurse)] Force=[$($Component.Force)]." `
            -Level INFO

        if (-not (Test-Path -LiteralPath $targetPath -PathType Container)) {
            $summary = "Directory [$targetPath] is not present; no deletion was necessary."

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message $summary `
                -Level SUCCESS

            return New-RaynetComponentResult `
                -Success $true `
                -ExitCode 0 `
                -AlreadyInDesiredState $true `
                -Data @{ Summary = $summary }
        }

        try {
            $item = Get-Item -LiteralPath $targetPath -Force -ErrorAction Stop
            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "Directory found. Attributes=[$($item.Attributes)] FullName=[$($item.FullName)]." `
                -Level DEBUG
        }
        catch {
            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "Directory exists but metadata could not be read: $($_.Exception.Message)" `
                -Level WARNING
        }

        $removeParams = @{
            LiteralPath = $targetPath
            ErrorAction = 'Stop'
        }

        if ([bool]$Component.Recurse) {
            $removeParams.Recurse = $true
        }

        if ([bool]$Component.Force) {
            $removeParams.Force = $true
        }

        $started = Get-Date
        Remove-Item @removeParams

        if ([int]$Component.TimeoutSeconds -gt 0) {
            $elapsedSeconds = ((Get-Date) - $started).TotalSeconds
            if ($elapsedSeconds -gt [int]$Component.TimeoutSeconds) {
                throw "Directory deletion exceeded timeout of [$($Component.TimeoutSeconds)] second(s)."
            }
        }

        if ([bool]$Component.Verify -and
            (Test-Path -LiteralPath $targetPath -PathType Container)) {
            throw "Directory deletion returned without error, but [$targetPath] still exists."
        }

        $summary = "Directory [$targetPath] was removed successfully."

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message $summary `
            -Level SUCCESS

        return New-RaynetComponentResult `
            -Success $true `
            -ExitCode 0 `
            -Data @{ Summary = $summary }
    }
    catch {
        $message = "DeleteDirectory failed for [$($Component.Path)]: $($_.Exception.Message)"

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message $message `
            -Level ERROR

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message $_.Exception.ToString() `
            -Level DEBUG

        return New-RaynetComponentResult `
            -Success $false `
            -ExitCode 1 `
            -Error $message `
            -ErrorMessage $_.Exception.ToString() `
            -Data @{ Summary = $message }
    }
}
