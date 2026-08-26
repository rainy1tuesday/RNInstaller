function Raynet_CopyFiles {
<#
.SYNOPSIS
    Defines a file-copy component.

.DESCRIPTION
    Defines the current file-copy DSL component. It copies a source file to a target file and supports overwrite policy and uninstall removal behavior.

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
    Raynet_CopyFiles -Name 'Copy configuration' -SourceFile 'Files\app.config' -TargetFile 'C:\ProgramData\MyApp\app.config'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_CopyFiles -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$SourceFile,[Parameter(Mandatory=$true)][string]$TargetFile,
[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][ValidateSet('Always','IfNewer','Never')][string]$Opt_OverwriteMode='Always',
[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
Add-RaynetComponent -Component @{Type='CopyFile';Name=$Name;SourceFile=$SourceFile;TargetFile=$TargetFile;Opt_Action=$Opt_Action;Opt_OverwriteMode=$Opt_OverwriteMode;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}
