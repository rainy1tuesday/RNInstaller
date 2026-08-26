function Raynet_RegModify {
<#
.SYNOPSIS
    Defines a Windows registry modification component.

.DESCRIPTION
    Sets or removes a registry value at a PowerShell registry-provider path, with optional value type/data for Set operations.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER RegistryPath
    PowerShell registry provider path, for example HKLM:\Software\Vendor\App.

.PARAMETER ValueName
    Registry value name.

.PARAMETER RegistryAction
    Registry operation: Set or Remove.

.PARAMETER ValueType
    Optional registry value type used by Set, for example REG_SZ or DWORD.

.PARAMETER ValueData
    Optional data written by RegistryAction Set.

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
    Raynet_RegModify -Name 'Configure MyApp' -RegistryPath 'HKLM:\SOFTWARE\MyCompany\MyApp' -ValueName 'Enabled' -RegistryAction Set -ValueType REG_DWORD -ValueData 1

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_RegModify -Full for complete native PowerShell help.
#>
[CmdletBinding()]param(
[Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$RegistryPath,[Parameter(Mandatory=$true)][string]$ValueName,[Parameter(Mandatory=$true)][ValidateSet('Set','Remove')][string]$RegistryAction,[Parameter(Mandatory=$false)][string]$ValueType,[Parameter(Mandatory=$false)]$ValueData,
[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true)
$c=@{Type='RegModify';Name=$Name;RegistryPath=$RegistryPath;ValueName=$ValueName;RegistryAction=$RegistryAction;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify};if($PSBoundParameters.ContainsKey('ValueType')){$c.ValueType=$ValueType};if($PSBoundParameters.ContainsKey('ValueData')){$c.ValueData=$ValueData};Add-RaynetComponent $c
}

function Invoke-RaynetRegModify {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Component,
        [Parameter(Mandatory = $true)]
        [string]$LogRoot,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install','Uninstall')]
        [string]$Action
    )

    $Logs = Get-RaynetComponentLogs `
        -Component $Component `
        -LogRoot $LogRoot `
        -Action 'RegModify'

    $WrapperLog = $Logs.WrapperLog

    try {

        foreach ($Property in @(
                'RegistryPath',
                'ValueName',
                'RegistryAction'
            )) {

            if (-not $Component.ContainsKey($Property)) {
                throw "Component [$($Component.Name)] is missing property [$Property]"
            }

            if ([string]::IsNullOrWhiteSpace($Component[$Property])) {
                throw "Component [$($Component.Name)] contains an empty property [$Property]"
            }
        }

        $RegistryAction = $Component.RegistryAction

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "RegistryPath [$($Component.RegistryPath)]"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "ValueName [$($Component.ValueName)]"

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Message "RegistryAction [$RegistryAction]"

        switch ($RegistryAction.ToLower()) {

            'set' {

                foreach ($Property in @(
                        'ValueType',
                        'ValueData'
                    )) {

                    if (-not $Component.ContainsKey($Property)) {
                        throw "Component [$($Component.Name)] is missing property [$Property]"
                    }
                }

                if (-not (Test-Path -LiteralPath $Component.RegistryPath)) {

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Message "Creating registry key [$($Component.RegistryPath)]"

                    New-Item `
                        -Path $Component.RegistryPath `
                        -Force `
                        -ErrorAction Stop | Out-Null
                }

                switch ($Component.ValueType.ToUpper()) {

                    'REG_SZ' {

                        New-ItemProperty `
                            -Path $Component.RegistryPath `
                            -Name $Component.ValueName `
                            -Value ([string]$Component.ValueData) `
                            -PropertyType String `
                            -Force `
                            -ErrorAction Stop | Out-Null
                    }

                    'DWORD' {

                        New-ItemProperty `
                            -Path $Component.RegistryPath `
                            -Name $Component.ValueName `
                            -Value ([int]$Component.ValueData) `
                            -PropertyType DWord `
                            -Force `
                            -ErrorAction Stop | Out-Null
                    }

                    default {
                        throw "Unsupported ValueType [$($Component.ValueType)]"
                    }
                }

                Write-RaynetInstallerLog `
                    -LogFile $WrapperLog `
                    -Level 'SUCCESS' `
                    -Message "Registry value written successfully"
            }

            'delete' {

                if (-not (Test-Path -LiteralPath $Component.RegistryPath)) {

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Level 'WARNING' `
                        -Message "Registry key not found [$($Component.RegistryPath)]"

                    return @{
                        Success  = $true
                        ExitCode = 0
                    }
                }

                $PropertyExists = $null -ne (Get-ItemProperty `
                        -Path $Component.RegistryPath `
                        -Name $Component.ValueName `
                        -ErrorAction SilentlyContinue)

                if ($PropertyExists) {

                    Remove-ItemProperty `
                        -Path $Component.RegistryPath `
                        -Name $Component.ValueName `
                        -ErrorAction Stop

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Level 'SUCCESS' `
                        -Message "Registry value deleted successfully"
                }
                else {

                    Write-RaynetInstallerLog `
                        -LogFile $WrapperLog `
                        -Level 'WARNING' `
                        -Message "Registry value not found [$($Component.ValueName)]"
                }
            }

            default {
                throw "Unsupported RegistryAction [$RegistryAction]"
            }
        }

        return @{
            Success  = $true
            ExitCode = 0
        }
    }
    catch {

        Write-RaynetInstallerLog `
            -LogFile $WrapperLog `
            -Level 'ERROR' `
            -Message $_.Exception.Message

        return @{
            Success      = $false
            ExitCode     = 1
            Error        = $_.Exception.Message
            ErrorMessage = $_.Exception.Message
        }
    }
}
