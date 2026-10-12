function Raynet_ModifyIni {
<#
.SYNOPSIS
    Defines an INI modification component.
.DESCRIPTION
    Applies one or more INI-file modifications using entries containing
    Section, Key, and Value properties.
.PARAMETER Name
    Human-readable component name used in package and component logging.
.PARAMETER IniFile
    INI file to modify.
.PARAMETER Entries
    One or more entries containing Section, Key, and Value properties.
.PARAMETER Opt_Action
    Controls which package action executes this component. Default follows the
    package Install or Uninstall action.
.PARAMETER Opt_Critical
    Controls whether a failure stops package execution.
.PARAMETER Opt_TimeoutSeconds
    Maximum execution time where supported. Zero means no explicit timeout.
.PARAMETER Opt_SuccessExitCodes
    Exit codes considered successful by components that launch external processes.
.PARAMETER Opt_RebootExitCodes
    Exit codes that mark the package as requiring a reboot.
.PARAMETER Opt_Force
    Requests execution even when the desired state is already satisfied, where supported.
.PARAMETER Opt_Verify
    Enables post-action verification where supported.
.EXAMPLE
    Raynet_ModifyIni -Name 'Configure MyApp' -IniFile 'C:\ProgramData\MyApp\app.ini' -Entries @(@{Section='General';Key='Language';Value='de'})
.INPUTS
    None. The function defines a component in the current Raynet package.
.OUTPUTS
    None. The component definition is registered with the Raynet framework.
.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_ModifyIni -Full for complete native PowerShell help.
#>
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][string]$IniFile,
        [Parameter(Mandatory)]$Entries,
        [ValidateSet('Default','Install','Uninstall')][string]$Opt_Action = 'Default',
        [bool]$Opt_Critical = $true,
        [int]$Opt_TimeoutSeconds = 0,
        [int[]]$Opt_SuccessExitCodes = @(0,3010),
        [int[]]$Opt_RebootExitCodes = @(3010,1641),
        [bool]$Opt_Force = $false,
        [bool]$Opt_Verify = $true
    )

    Add-RaynetComponent -Component @{
        Type = 'ModifyIni'
        Name = $Name
        IniFile = $IniFile
        Entries = $Entries
        Opt_Action = $Opt_Action
        Opt_Critical = $Opt_Critical
        Opt_TimeoutSeconds = $Opt_TimeoutSeconds
        Opt_SuccessExitCodes = $Opt_SuccessExitCodes
        Opt_RebootExitCodes = $Opt_RebootExitCodes
        Opt_Force = $Opt_Force
        Opt_Verify = $Opt_Verify
    }
}

function Invoke-RaynetModifyIni {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)][hashtable]$Component,
        [Parameter(Mandatory)][string]$LogRoot,
        [Parameter(Mandatory)][ValidateSet('Install','Uninstall')][string]$Action
    )

    $log = (Get-RaynetComponentLogs -Component $Component -LogRoot $LogRoot -Action $Action).WrapperLog

    try {
        foreach ($property in 'IniFile','Entries') {
            if (-not $Component.ContainsKey($property) -or $null -eq $Component[$property]) {
                throw "Component [$($Component.Name)] is missing property [$property]."
            }
        }

        if (-not (Test-Path -LiteralPath $Component.IniFile -PathType Leaf)) {
            throw "INI file not found [$($Component.IniFile)]"
        }

        $lines = [System.Collections.ArrayList]::new()
        Get-Content -LiteralPath $Component.IniFile -ErrorAction Stop | ForEach-Object {
            [void]$lines.Add($_)
        }

        foreach ($entry in $Component.Entries) {
            if ([string]::IsNullOrWhiteSpace($entry.Section)) {
                throw "Entry in component [$($Component.Name)] is missing Section."
            }

            if ([string]::IsNullOrWhiteSpace($entry.Key)) {
                throw "Entry in component [$($Component.Name)] is missing Key."
            }

            $sectionStart = -1
            $sectionEnd = $lines.Count

            for ($index = 0; $index -lt $lines.Count; $index++) {
                if ($lines[$index].Trim() -eq "[$($entry.Section)]") {
                    $sectionStart = $index
                    for ($nextIndex = $index + 1; $nextIndex -lt $lines.Count; $nextIndex++) {
                        if ($lines[$nextIndex] -match '^\[.*\]$') {
                            $sectionEnd = $nextIndex
                            break
                        }
                    }
                    break
                }
            }

            if ($sectionStart -ge 0) {
                $keyFound = $false
                for ($index = $sectionStart + 1; $index -lt $sectionEnd; $index++) {
                    if ($lines[$index].Trim().StartsWith("$($entry.Key)=")) {
                        $lines[$index] = "$($entry.Key)=$($entry.Value)"
                        $keyFound = $true
                        break
                    }
                }

                if (-not $keyFound) {
                    [void]$lines.Insert($sectionEnd, "$($entry.Key)=$($entry.Value)")
                }
            }
            else {
                if ($lines.Count -gt 0) {
                    [void]$lines.Add('')
                }
                [void]$lines.Add("[$($entry.Section)]")
                [void]$lines.Add("$($entry.Key)=$($entry.Value)")
            }
        }

        Set-Content -LiteralPath $Component.IniFile -Value $lines -Encoding ASCII -ErrorAction Stop
        $summary = "INI file [$($Component.IniFile)] was updated successfully."
        Write-RaynetInstallerLog -LogFile $log -Message $summary -Level SUCCESS
        return New-RaynetComponentResult -Success $true -ExitCode 0 -Data @{ Summary = $summary }
    }
    catch {
        Write-RaynetInstallerLog -LogFile $log -Message $_.Exception.Message -Level ERROR
        return New-RaynetComponentResult `
            -Success $false `
            -ExitCode 1 `
            -Error $_.Exception.Message `
            -ErrorMessage $_.Exception.ToString() `
            -Data @{ Summary = "INI modification failed. Reason: $($_.Exception.Message)" }
    }
}
