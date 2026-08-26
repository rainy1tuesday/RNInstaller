function Raynet_DeleteFiles {
<#
.SYNOPSIS
    Defines a file deletion component.

.DESCRIPTION
    Deletes files matching a pattern from a target folder. Hidden/read-only files are included by the implementation where permissions permit; missing targets are treated as an already-satisfied state.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER TargetFolder
    Folder in which matching files are deleted.

.PARAMETER FilePattern
    File name or wildcard pattern selecting files to delete.

.PARAMETER Opt_DeleteEmptyDirectories
    Remove empty directories after file deletion. Default: $false.

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
    Raynet_DeleteFiles -Name 'Remove old files' -TargetFolder 'C:\ProgramData\MyApp' -FilePattern '*.old' -Opt_DeleteEmptyDirectories $true

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_DeleteFiles -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$TargetFolder,[Parameter(Mandatory=$false)][string]$FilePattern='*.*',
[Parameter(Mandatory=$false)][bool]$Opt_DeleteEmptyDirectories=$false,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
Add-RaynetComponent -Component @{Type='DeleteFiles';Name=$Name;TargetFolder=$TargetFolder;FilePattern=$FilePattern;Opt_DeleteEmptyDirectories=$Opt_DeleteEmptyDirectories;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}

function Invoke-RaynetDeleteFiles {
    param([Parameter(Mandatory=$true)][hashtable]$Component,[Parameter(Mandatory=$true)][string]$LogRoot,[Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$Action)
    $Logs=Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action; $log=$Logs.WrapperLog
    try {
        foreach($p in 'TargetFolder','FilePattern'){if(-not $Component.ContainsKey($p) -or [string]::IsNullOrWhiteSpace($Component[$p])){throw "Component [$($Component.Name)] is missing property [$p]."}}
        $empty=if($Component.ContainsKey('Opt_DeleteEmptyDirectories')){[bool]$Component.Opt_DeleteEmptyDirectories}else{$true}
        Write-RaynetInstallerLog $log "DeleteFiles started. Action=[$Action] Folder=[$($Component.TargetFolder)] Pattern=[$($Component.FilePattern)]"
        if($Action -eq 'Install'){Write-RaynetInstallerLog -LogFile $log -Message 'DeleteFiles is destructive and is normally install-only; executing requested operation.' -Level WARNING}
        if(-not(Test-Path -LiteralPath $Component.TargetFolder)){$summary="Target folder [$($Component.TargetFolder)] is not present; nothing needed to be deleted.";Write-RaynetInstallerLog -LogFile $log -Message $summary -Level INFO; return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState:$true -Data @{Summary=$summary}}
        $access=Test-RaynetPathAccess -Path $Component.TargetFolder -Mode Write -LogFile $log -Label 'Delete target folder'
        if(-not $access.Accessible){throw "Target folder is not accessible [$($Component.TargetFolder)]"}
        $files=@(Get-ChildItem -LiteralPath $Component.TargetFolder -Filter $Component.FilePattern -File -Recurse -Force -ErrorAction Stop)
        Write-RaynetInstallerLog $log "Matched $($files.Count) file(s)."
        foreach($f in $files){
            Test-RaynetPathAccess -Path $f.FullName -Mode ReadWrite -LogFile $log -Label 'File before delete' | Out-Null
            Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop
            if(Test-Path -LiteralPath $f.FullName){throw "Delete verification failed [$($f.FullName)]"}
            Write-RaynetInstallerLog $log "Deleted [$($f.FullName)]"
        }
        if($empty){$dirs=@(Get-ChildItem -LiteralPath $Component.TargetFolder -Directory -Recurse -Force -ErrorAction Stop|Sort-Object FullName -Descending);foreach($d in $dirs){if(-not(Get-ChildItem -LiteralPath $d.FullName -Force -ErrorAction Stop)){Remove-Item -LiteralPath $d.FullName -Force -Recurse -ErrorAction Stop;Write-RaynetInstallerLog $log "Deleted empty directory [$($d.FullName)]"}}}
        Write-RaynetInstallerLog -LogFile $log -Message 'DeleteFiles completed successfully.' -Level SUCCESS
        $summary=if($files.Count -eq 0){"No matching files were present; no deletion was necessary."}else{"Deleted [$($files.Count)] matching file(s) successfully."}; return New-RaynetComponentResult -Success $true -ExitCode 0 -AlreadyInDesiredState:($files.Count -eq 0) -Data @{Summary=$summary}
    } catch {Write-RaynetInstallerLog $log $_.Exception.Message ERROR;return New-RaynetComponentResult -Success $false -ExitCode 1 -Error $_.Exception.Message -ErrorMessage $_.Exception.ToString()}
}
