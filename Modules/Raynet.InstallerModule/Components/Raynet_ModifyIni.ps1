function Raynet_ModifyIni {
<#
.SYNOPSIS
    Defines an INI modification component.

.DESCRIPTION
    Applies one or more INI-file modifications using the framework Entries structure. Multiple sections and key/value changes can be represented in one component.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER IniFile
    INI file to modify.

.PARAMETER Entries
    INI modifications passed to the implementation. Supports the framework entry structure for one or more sections/values.

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
    Raynet_ModifyIni -Name 'Configure MyApp' -IniFile 'C:\ProgramData\MyApp\app.ini' -Entries @{ General = @{ Language = 'de'; Enabled = '1' } }

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_ModifyIni -Full for complete native PowerShell help.
#>
[CmdletBinding()]param([Parameter(Mandatory=$true)][string]$Name,[Parameter(Mandatory=$true)][string]$IniFile,[Parameter(Mandatory=$true)]$Entries,[Parameter(Mandatory=$false)][ValidateSet('Default','Install','Uninstall')][string]$Opt_Action='Default',[Parameter(Mandatory=$false)][bool]$Opt_Critical=$true,[Parameter(Mandatory=$false)][int]$Opt_TimeoutSeconds=0,[Parameter(Mandatory=$false)][int[]]$Opt_SuccessExitCodes=@(0,3010),[Parameter(Mandatory=$false)][int[]]$Opt_RebootExitCodes=@(3010,1641),[Parameter(Mandatory=$false)][bool]$Opt_Force=$false,[Parameter(Mandatory=$false)][bool]$Opt_Verify=$true);Add-RaynetComponent @{Type='ModifyIni';Name=$Name;IniFile=$IniFile;Entries=$Entries;Opt_Action=$Opt_Action;Opt_Critical=$Opt_Critical;Opt_TimeoutSeconds=$Opt_TimeoutSeconds;Opt_SuccessExitCodes=$Opt_SuccessExitCodes;Opt_RebootExitCodes=$Opt_RebootExitCodes;Opt_Force=$Opt_Force;Opt_Verify=$Opt_Verify}
}

function Invoke-RaynetModifyIni {
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Component,
        [Parameter(Mandatory = $true)]
        [string]$LogRoot,
        [Parameter(Mandatory = $true)]
        [ValidateSet('Install','Uninstall')]
        [string]$Action
    )

    try {
        #
        # Validate Component
        #

        if (-not $Component.ContainsKey("IniFile")) {
            throw "Component [$($Component.Name)] is missing property [IniFile]."
        }

        if (-not (Test-Path -LiteralPath $Component.IniFile)) {
            throw "INI file not found [$($Component.IniFile)]"
        }

        if (-not $Component.ContainsKey("Entries")) {
            throw "Component [$($Component.Name)] is missing property [Entries]."
            #
            # Load file into editable array
            #
        }
        $Lines = [System.Collections.ArrayList]::new()

        Get-Content -Path $Component.IniFile | ForEach-Object {
            [void]$Lines.Add($_)
        }
        
        #
        # Process all Entries
        #

        foreach ($Entry in $Component.Entries) {
            
            if ([string]::IsNullOrWhiteSpace($Entry.Section)) {
                throw "Entry in component [$($Component.Name)] is missing Section."
            }

            if ([string]::IsNullOrWhiteSpace($Entry.Key)) {
                throw "Entry in component [$($Component.Name)] is missing Key."
            }

            $Section = $Entry.Section
            $Key = $Entry.Key
            $Value = $Entry.Value

            $SectionFound = $false
            $KeyFound = $false

            $SectionStart = -1
            $SectionEnd = $Lines.Count

            #
            # Find Section
            #

            for ($i = 0; $i -lt $Lines.Count; $i++) {
                if ($Lines[$i].Trim() -eq "[$Section]") {
                    $SectionFound = $true
                    $SectionStart = $i

                    #
                    # Find next section
                    #

                    for ($j = $i + 1; $j -lt $Lines.Count; $j++) {
                        if ($Lines[$j] -match '^\[.*\]$') {
                            $SectionEnd = $j
                            break
                        }
                    }

                    break
                }
            }

            #
            # Section exists
            #

            if ($SectionFound) {
                #
                # Search Key
                #

                for ($i = $SectionStart + 1; $i -lt $SectionEnd; $i++) {
                    $CurrentLine = $Lines[$i].Trim()

                    if ($CurrentLine.StartsWith("$Key=")) {
                        $Lines[$i] = "$Key=$Value"

                        $KeyFound = $true

                        break
                    }
                }

                #
                # Key missing -> create it
                #

                if (-not $KeyFound) {
                    [void]$Lines.Insert(
                        $SectionEnd,
                        "$Key=$Value"
                    )
                }
            }
            else {
                #
                # Section missing -> create section and key
                #

                if ($Lines.Count -gt 0) {
                    [void]$Lines.Add("")
                }

                [void]$Lines.Add("[$Section]")
                [void]$Lines.Add("$Key=$Value")
            }
        }

        #
        # Save File
        #

        Set-Content `
            -Path $Component.IniFile `
            -Value $Lines `
            -Encoding ASCII

        return @{
            Success  = $true
            ExitCode = 0
        }
    }
    catch {
        return @{
            Success      = $false
            ExitCode     = 1
            Error        = $_.Exception.Message
            ErrorMessage = $_.Exception.Message
        }
    }
}
