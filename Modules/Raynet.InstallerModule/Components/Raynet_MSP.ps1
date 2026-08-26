function Raynet_MSP {
<#
.SYNOPSIS
    Defines a Windows Installer MSP patch component.

.DESCRIPTION
    Applies or removes an MSP patch. Patch identity is discovered from the MSP when possible; optional patch/product GUID overrides are available. Windows Installer operations always use /qn /norestart.

.PARAMETER Name
    Human-readable component name used in package and component logging.

.PARAMETER FileName
    Path to the target file. For MSP/XML components, relative paths are resolved against the package script directory.

.PARAMETER Opt_Arguments
    Additional command-line arguments or task arguments, depending on component.

.PARAMETER Opt_PatchCode
    Optional MSP patch GUID override. Normally discovered from the MSP when possible.

.PARAMETER Opt_ProductCode
    Optional MSI product GUID override for MSP detection/uninstall.

.PARAMETER Opt_Action
    Controls which package action executes this component. 'Default' follows the package Install/Uninstall action; 'Install' or 'Uninstall' overrides it for this component. Default: Default.

.PARAMETER Opt_Critical
    Controls failure handling. When true, a component failure stops package execution. When false, the failure is logged and the package continues. Default: $true.

.PARAMETER Opt_Verify
    Enables post-action verification where supported. Default: $true.

.PARAMETER Opt_Force
    Requests execution even when the component would otherwise consider the desired state already satisfied, where supported. Default: $false.

.PARAMETER Opt_TimeoutSeconds
    Maximum component execution time in seconds where the implementation supports a timeout. A value of 0 means no explicit component timeout. Default: 0.

.PARAMETER Opt_SuccessExitCodes
    Exit codes considered successful by components that launch external installers/processes. Default: @(0,3010).

.PARAMETER Opt_RebootExitCodes
    Exit codes that mark the package as requiring a reboot. Default: @(3010,1641).

.PARAMETER Opt_LogMSI
    Generate verbose native Windows Installer logging for the MSP operation. Default: $true.

.EXAMPLE
    Raynet_MSP -Name 'Patch MyApp' -FileName 'Files\MyPatch.msp'

.EXAMPLE
    Raynet_MSP -Name 'Remove MyPatch' -FileName 'Files\MyPatch.msp' -Opt_Action Uninstall -Opt_ProductCode '{11111111-2222-3333-4444-555555555555}' -Opt_PatchCode '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}'

.INPUTS
    None. The function defines a component in the current Raynet package.

.OUTPUTS
    None. The component definition is registered with the Raynet framework.

.NOTES
    Raynet Installer Framework 0.4.
    Use Get-Help Raynet_MSP -Full for complete native PowerShell help.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Name,

        [Parameter(Mandatory)]
        [string]$FileName,

        [string]$Opt_Arguments,

        [ValidatePattern('^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$')]
        [string]$Opt_PatchCode,

        [ValidatePattern('^\{?[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}?$')]
        [string]$Opt_ProductCode,

        [ValidateSet('Default','Install','Uninstall')]
        [string]$Opt_Action = 'Default',

        [bool]$Opt_Critical = $true,
        [bool]$Opt_Verify = $true,
        [bool]$Opt_Force = $false,

        [ValidateRange(0,2147483647)]
        [int]$Opt_TimeoutSeconds = 0,

        [int[]]$Opt_SuccessExitCodes = @(0,3010),
        [int[]]$Opt_RebootExitCodes = @(3010,1641),

        [bool]$Opt_LogMSI = $true
    )

    $component = @{
        Type                 = 'MSP'
        Name                 = $Name
        FileName             = $FileName
        Opt_Action           = $Opt_Action
        Opt_Critical         = $Opt_Critical
        Opt_Verify           = $Opt_Verify
        Opt_Force            = $Opt_Force
        Opt_TimeoutSeconds   = $Opt_TimeoutSeconds
        Opt_SuccessExitCodes = $Opt_SuccessExitCodes
        Opt_RebootExitCodes  = $Opt_RebootExitCodes
        Opt_LogMSI           = $Opt_LogMSI
    }

    foreach ($parameterName in @('Opt_Arguments','Opt_PatchCode','Opt_ProductCode')) {
        if ($PSBoundParameters.ContainsKey($parameterName)) {
            $component[$parameterName] = Get-Variable -Name $parameterName -ValueOnly
        }
    }

    Add-RaynetComponent -Component $component
}

function ConvertTo-RaynetInstallerGuid {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Guid
    )

    $value = $Guid.Trim().Trim('{','}')
    return ('{' + $value.ToUpperInvariant() + '}')
}

function Get-RaynetMSPPatchCode {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$FileName
    )

    $installer = $null
    $database = $null
    $summary = $null

    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer
        $database = $installer.OpenDatabase($FileName, 0)
        $summary = $database.SummaryInformation(0)
        $revision = [string]$summary.Property(9)

        $match = [regex]::Match(
            $revision,
            '\{[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}\}'
        )

        if ($match.Success) {
            return ConvertTo-RaynetInstallerGuid -Guid $match.Value
        }

        return $null
    }
    finally {
        foreach ($comObject in @($summary,$database,$installer)) {
            if ($null -ne $comObject -and [System.Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObject)
            }
        }
    }
}

function Get-RaynetInstallerStringListValues {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        $StringList
    )

    $values = [System.Collections.Generic.List[string]]::new()

    try {
        $count = [int]$StringList.Count
        for ($index = 0; $index -lt $count; $index++) {
            $values.Add([string]$StringList.Item($index))
        }
    }
    catch {
        foreach ($value in $StringList) {
            $values.Add([string]$value)
        }
    }

    return @($values)
}

function Get-RaynetMSPInstalledProducts {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PatchCode,

        [string]$ProductCode
    )

    $patchCodeNormalized = ConvertTo-RaynetInstallerGuid -Guid $PatchCode
    $installer = $null
    $productsCollection = $null

    try {
        $installer = New-Object -ComObject WindowsInstaller.Installer

        if (-not [string]::IsNullOrWhiteSpace($ProductCode)) {
            $products = @(ConvertTo-RaynetInstallerGuid -Guid $ProductCode)
        }
        else {
            $productsCollection = $installer.Products
            $products = Get-RaynetInstallerStringListValues -StringList $productsCollection
        }

        $matches = [System.Collections.Generic.List[string]]::new()

        foreach ($product in $products) {
            $patchesCollection = $null

            try {
                $normalizedProduct = ConvertTo-RaynetInstallerGuid -Guid $product
                $patchesCollection = $installer.Patches($normalizedProduct)
                $patches = Get-RaynetInstallerStringListValues -StringList $patchesCollection

                foreach ($patch in $patches) {
                    if ((ConvertTo-RaynetInstallerGuid -Guid $patch) -eq $patchCodeNormalized) {
                        $matches.Add($normalizedProduct)
                        break
                    }
                }
            }
            catch {
                # Product may not expose a patch collection; continue discovery.
            }
            finally {
                if ($null -ne $patchesCollection -and
                    [System.Runtime.InteropServices.Marshal]::IsComObject($patchesCollection)) {
                    [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($patchesCollection)
                }
            }
        }

        return @($matches | Select-Object -Unique)
    }
    finally {
        if ($null -ne $productsCollection -and
            [System.Runtime.InteropServices.Marshal]::IsComObject($productsCollection)) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($productsCollection)
        }

        if ($null -ne $installer -and
            [System.Runtime.InteropServices.Marshal]::IsComObject($installer)) {
            [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($installer)
        }
    }
}

function Raynet_TestMSPInstalled {
<#
.SYNOPSIS
    Tests whether an MSP patch is installed.

.DESCRIPTION
    Queries Windows Installer patch registration for the supplied PatchCode. An optional ProductCode can restrict detection to one product; otherwise all registered products are considered.

.PARAMETER PatchCode
    MSP patch code GUID to detect.

.PARAMETER ProductCode
    Optional MSI product code GUID used to restrict patch detection to one product.

.EXAMPLE
    Raynet_TestMSPInstalled -PatchCode '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}'

.EXAMPLE
    Raynet_TestMSPInstalled -PatchCode '{AAAAAAAA-BBBB-CCCC-DDDD-EEEEEEEEEEEE}' -ProductCode '{11111111-2222-3333-4444-555555555555}'

.OUTPUTS
    System.Boolean. True when the patch is registered for the selected product scope; otherwise false.

.NOTES
    Raynet Installer Framework 0.4. Primarily an internal MSP detection helper, but currently exported by the module naming convention.
#>

    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$PatchCode,

        [string]$ProductCode
    )

    $products = Get-RaynetMSPInstalledProducts `
        -PatchCode $PatchCode `
        -ProductCode $ProductCode

    return ($products.Count -gt 0)
}

function Invoke-RaynetMSPMsiexec {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [string]$Arguments,

        [ValidateRange(0,2147483647)]
        [int]$TimeoutSeconds = 0
    )

    $process = Start-Process `
        -FilePath 'msiexec.exe' `
        -ArgumentList $Arguments `
        -PassThru `
        -ErrorAction Stop

    if ($TimeoutSeconds -gt 0) {
        $completed = $process.WaitForExit($TimeoutSeconds * 1000)

        if (-not $completed) {
            try {
                $process.Kill()
                $process.WaitForExit()
            }
            catch {
            }

            throw "msiexec exceeded timeout of [$TimeoutSeconds] second(s)."
        }
    }
    else {
        $process.WaitForExit()
    }

    return [int]$process.ExitCode
}

function Invoke-RaynetMSP {
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
    $msiLog = $logs.MsiLog

    try {
        $fileName = [string]$Component.FileName

        if ([string]::IsNullOrWhiteSpace($fileName)) {
            throw 'MSP FileName is empty.'
        }

        $patchCode = $null

        if ($Component.ContainsKey('Opt_PatchCode') -and
            -not [string]::IsNullOrWhiteSpace([string]$Component.Opt_PatchCode)) {
            $patchCode = ConvertTo-RaynetInstallerGuid -Guid ([string]$Component.Opt_PatchCode)
        }
        elseif (Test-Path -LiteralPath $fileName -PathType Leaf) {
            $patchCode = Get-RaynetMSPPatchCode -FileName $fileName
        }

        $productCode = $null
        if ($Component.ContainsKey('Opt_ProductCode') -and
            -not [string]::IsNullOrWhiteSpace([string]$Component.Opt_ProductCode)) {
            $productCode = ConvertTo-RaynetInstallerGuid -Guid ([string]$Component.Opt_ProductCode)
        }

        if (-not [string]::IsNullOrWhiteSpace($patchCode)) {
            $Component['Opt_PatchCode'] = $patchCode
        }

        if (-not [string]::IsNullOrWhiteSpace($productCode)) {
            $Component['Opt_ProductCode'] = $productCode
        }

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "MSP action [$Action]. File=[$fileName] PatchCode=[$patchCode] ProductCode=[$productCode]." `
            -Level INFO

        if ($Action -eq 'Install') {
            $access = Test-RaynetPathAccess `
                -Path $fileName `
                -Mode Read `
                -LogFile $log `
                -Label 'MSP source'

            if (-not $access.Readable) {
                throw "MSP source is not readable [$fileName]."
            }

            if ([string]::IsNullOrWhiteSpace($patchCode) -and
                ([bool]$Component.Verify -or -not [bool]$Component.Force)) {
                throw "PatchCode could not be discovered from MSP [$fileName]. Supply -Opt_PatchCode for reliable detection."
            }

            $alreadyInstalled = $false
            if (-not [string]::IsNullOrWhiteSpace($patchCode)) {
                $alreadyInstalled = Raynet_TestMSPInstalled `
                    -PatchCode $patchCode `
                    -ProductCode $productCode
            }

            if ($alreadyInstalled -and -not [bool]$Component.Force) {
                $summary = "Patch [$patchCode] is already installed; no action was necessary."

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

            $arguments = "/p `"$fileName`" /qn /norestart"

            if ($Component.Opt_Arguments) {
                $arguments += " $($Component.Opt_Arguments)"
            }

            if ($Component.Opt_LogMSI) {
                $arguments += " /L*v `"$msiLog`""
            }

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "Executing Windows Installer patch installation. PatchCode=[$patchCode]." `
                -Level INFO

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "msiexec.exe $arguments" `
                -Level DEBUG

            $exitCode = Invoke-RaynetMSPMsiexec `
                -Arguments $arguments `
                -TimeoutSeconds ([int]$Component.TimeoutSeconds)

            $rebootRequired = ($exitCode -in @($Component.RebootCodes))

            if ($exitCode -notin @($Component.SuccessCodes) -and -not $rebootRequired) {
                throw "MSP installation failed with msiexec ExitCode=[$exitCode]."
            }

            if ([bool]$Component.Verify) {
                $installedAfter = Raynet_TestMSPInstalled `
                    -PatchCode $patchCode `
                    -ProductCode $productCode

                if (-not $installedAfter) {
                    throw "MSP installation returned success, but patch [$patchCode] was not detected afterward."
                }
            }

            $summary = "Patch [$patchCode] installed successfully."

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "$summary RebootRequired=[$rebootRequired]." `
                -Level SUCCESS

            return New-RaynetComponentResult `
                -Success $true `
                -ExitCode $(if ($rebootRequired) { 3010 } else { 0 }) `
                -RebootRequired $rebootRequired `
                -Data @{ Summary = $summary }
        }

        if ([string]::IsNullOrWhiteSpace($patchCode)) {
            throw "PatchCode is required for MSP uninstall and could not be discovered. Supply -Opt_PatchCode or keep the MSP file available."
        }

        $installedProducts = Get-RaynetMSPInstalledProducts `
            -PatchCode $patchCode `
            -ProductCode $productCode

        if ($installedProducts.Count -eq 0) {
            $summary = "Patch [$patchCode] is not installed; uninstall state is already satisfied."

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

        $rebootRequired = $false

        foreach ($installedProduct in $installedProducts) {
            $productLog = $msiLog

            if ($installedProducts.Count -gt 1 -and [bool]$Component.Opt_LogMSI) {
                $safeProduct = ConvertTo-RaynetSafePathName -Name $installedProduct
                $directory = Split-Path -Parent $msiLog
                $baseName = [System.IO.Path]::GetFileNameWithoutExtension($msiLog)
                $productLog = Join-Path $directory ("{0}_{1}.log" -f $baseName, $safeProduct)
            }

            $arguments = "/package `"$installedProduct`" /uninstall `"$patchCode`" /qn /norestart"

            if ($Component.Opt_Arguments) {
                $arguments += " $($Component.Opt_Arguments)"
            }

            if ($Component.Opt_LogMSI) {
                $arguments += " /L*v `"$productLog`""
            }

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "Removing patch [$patchCode] from product [$installedProduct]." `
                -Level INFO

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "msiexec.exe $arguments" `
                -Level DEBUG

            $exitCode = Invoke-RaynetMSPMsiexec `
                -Arguments $arguments `
                -TimeoutSeconds ([int]$Component.TimeoutSeconds)

            $thisReboot = ($exitCode -in @($Component.RebootCodes))
            if ($thisReboot) {
                $rebootRequired = $true
            }

            if ($exitCode -notin @($Component.SuccessCodes) -and
                $exitCode -ne 1605 -and
                -not $thisReboot) {
                throw "MSP uninstall failed for product [$installedProduct] with msiexec ExitCode=[$exitCode]."
            }
        }

        if ([bool]$Component.Verify) {
            $stillInstalled = Raynet_TestMSPInstalled `
                -PatchCode $patchCode `
                -ProductCode $productCode

            if ($stillInstalled) {
                throw "MSP uninstall returned success, but patch [$patchCode] is still registered."
            }
        }

        $summary = "Patch [$patchCode] removed successfully from [$($installedProducts.Count)] product(s)."

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "$summary RebootRequired=[$rebootRequired]." `
            -Level SUCCESS

        return New-RaynetComponentResult `
            -Success $true `
            -ExitCode $(if ($rebootRequired) { 3010 } else { 0 }) `
            -RebootRequired $rebootRequired `
            -Data @{ Summary = $summary }
    }
    catch {
        $message = $_.Exception.Message

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
