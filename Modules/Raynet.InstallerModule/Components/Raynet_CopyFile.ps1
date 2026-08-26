function Raynet_CopyFile {
<#
.SYNOPSIS
    Deprecated compatibility wrapper for Raynet_CopyFiles.

.DESCRIPTION
    Provides backward compatibility for the older singular command name. New package scripts should use Raynet_CopyFiles.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER SourceFile
    Source file to copy. Relative paths are resolved against the main package script directory. UNC paths are supported when accessible.

.PARAMETER TargetFile
    Destination file path.

.PARAMETER Opt_Action
    Controls which package action executes this component. 'Default' follows the package Install/Uninstall action; 'Install' or 'Uninstall' overrides it for this component. Default: Default.

.PARAMETER Opt_OverwriteMode
    Controls replacement of an existing destination file: Always, IfNewer, or Never. Default: Always.

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
    Raynet_CopyFile -Name 'Copy configuration' -SourceFile 'Files\app.config' -TargetFile 'C:\ProgramData\MyApp\app.config'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_CopyFile -Full for complete native PowerShell help.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$SourceFile,
        [Parameter(Mandatory)][string]$TargetFile,
        [ValidateSet('Default','Install','Uninstall')][string]$Opt_Action = 'Default',
        [ValidateSet('Always','IfNewer','Never')][string]$Opt_OverwriteMode = 'Always',
        [bool]$Opt_Critical = $true,
        [int]$Opt_TimeoutSeconds = 0,
        [int[]]$Opt_SuccessExitCodes = @(0,3010),
        [int[]]$Opt_RebootExitCodes = @(3010,1641),
        [bool]$Opt_Force = $false,
        [bool]$Opt_Verify = $true
    )

    Write-Warning 'Raynet_CopyFile is deprecated. Use Raynet_CopyFiles.'
    Raynet_CopyFiles `
        -Name $Name `
        -SourceFile $SourceFile `
        -TargetFile $TargetFile `
        -Opt_Action $Opt_Action `
        -Opt_OverwriteMode $Opt_OverwriteMode `
        -Opt_Critical $Opt_Critical `
        -Opt_TimeoutSeconds $Opt_TimeoutSeconds `
        -Opt_SuccessExitCodes $Opt_SuccessExitCodes `
        -Opt_RebootExitCodes $Opt_RebootExitCodes `
        -Opt_Force $Opt_Force `
        -Opt_Verify $Opt_Verify
}

function Invoke-RaynetCopyFile {
    param([Parameter(Mandatory=$true)][hashtable]$Component,[Parameter(Mandatory=$true)][string]$LogRoot,[Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Action)
    $Logs=Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action; $log=$Logs.WrapperLog
    try {
        foreach($p in 'SourceFile','TargetFile'){if(-not $Component.ContainsKey($p) -or [string]::IsNullOrWhiteSpace($Component[$p])){throw "Component [$($Component.Name)] is missing property [$p]."}}
        $mode=if($Component.ContainsKey('Opt_OverwriteMode')){$Component.Opt_OverwriteMode}else{'Always'}
        if($mode -notin 'Always','IfNewer','Never'){throw "Invalid Opt_OverwriteMode [$mode]."}
        Write-RaynetInstallerLog $log "CopyFile started. Action=[$Action] Source=[$($Component.SourceFile)] Target=[$($Component.TargetFile)] OverwriteMode=[$mode]"
        if($Action -eq 'Uninstall'){
            if(Test-Path -LiteralPath $Component.TargetFile){
                Test-RaynetPathAccess -Path $Component.TargetFile -Mode ReadWrite -LogFile $log -Label 'Target before delete' | Out-Null
                Remove-Item -LiteralPath $Component.TargetFile -Force -ErrorAction Stop
                if(Test-Path -LiteralPath $Component.TargetFile){throw "Delete verification failed [$($Component.TargetFile)]"}
                Write-RaynetInstallerLog -LogFile $log -Message "Removed target file [$($Component.TargetFile)]" -Level SUCCESS
            } else { Write-RaynetInstallerLog -LogFile $log -Message "Target file not present; nothing to uninstall." -Level WARNING }
            return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState:$false
        }
        $srcTest=Test-RaynetPathAccess -Path $Component.SourceFile -Mode Read -LogFile $log -Label 'Source'
        if(-not $srcTest.Exists -or -not $srcTest.Readable){throw "Source file is not readable [$($Component.SourceFile)]"}
        $targetFolder=Split-Path $Component.TargetFile -Parent
        if(-not(Test-Path -LiteralPath $targetFolder)){New-Item -Path $targetFolder -ItemType Directory -Force -ErrorAction Stop|Out-Null; Write-RaynetInstallerLog $log "Created target folder [$targetFolder]"}
        Test-RaynetPathAccess -Path $targetFolder -Mode Write -LogFile $log -Label 'Target folder' | Out-Null
        $doCopy=$true
        if(Test-Path -LiteralPath $Component.TargetFile){
            $t=Test-RaynetPathAccess -Path $Component.TargetFile -Mode ReadWrite -LogFile $log -Label 'Existing target'
            if($mode -eq 'Never'){throw "Target file already exists [$($Component.TargetFile)]"}
            if($mode -eq 'IfNewer' -and (Get-Item $Component.SourceFile).LastWriteTime -le (Get-Item $Component.TargetFile).LastWriteTime){$doCopy=$false;Write-RaynetInstallerLog -LogFile $log -Message 'Target is newer or same age; copy skipped.' -Level WARNING}
            if($doCopy -and -not $t.Writable){throw "Target file is not writable [$($Component.TargetFile)]"}
        }
        if($doCopy){Copy-Item -LiteralPath $Component.SourceFile -Destination $Component.TargetFile -Force -ErrorAction Stop; Write-RaynetInstallerLog $log 'Copy operation completed.'}
        $verify=Test-RaynetPathAccess -Path $Component.TargetFile -Mode Read -LogFile $log -Label 'Copied target'
        if(-not $verify.Exists -or -not $verify.Readable){throw "Copy verification failed [$($Component.TargetFile)]"}
        $s=Get-Item $Component.SourceFile; $t=Get-Item $Component.TargetFile
        Write-RaynetInstallerLog -LogFile $log -Message "Verified target. Size=$($t.Length) bytes; LastWriteTime=$($t.LastWriteTime); SourceSize=$($s.Length) bytes." -Level SUCCESS
        return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState:(-not $doCopy)
    } catch { Write-RaynetInstallerLog $log $_.Exception.Message ERROR; return New-RaynetComponentResult -Success $false -ExitCode 1 -Error $_.Exception.Message -ErrorMessage $_.Exception.ToString() }
}
