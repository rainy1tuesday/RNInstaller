<#
.SYNOPSIS
    Executes a Raynet Installer package.
.DESCRIPTION
    Runs normalized package components, handles logging, critical failures,
    reboot propagation and package detection state.
#>
function Invoke-RaynetPackage {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [ValidateSet('Install','Uninstall')]
        [string]$Action,

        [Parameter(Mandatory)][string]$AppName,
        [Parameter(Mandatory)][string]$AppVersion,
        [Parameter(Mandatory)][string]$PackageRevision,
        [Parameter(Mandatory)][array]$Components,
        [string]$DetectionRoot,
        [string]$LogRoot,
        [string]$ConfigPath
    )

    $cfg = Get-RaynetConfiguration -ConfigPath $ConfigPath
    $script:RaynetConfiguredLogLevel = [string]$cfg.Logging.Level

    if (-not $PSBoundParameters.ContainsKey('DetectionRoot')) {
        $DetectionRoot = [string]$cfg.Paths.DetectionRoot
    }
    if (-not $PSBoundParameters.ContainsKey('LogRoot')) {
        $LogRoot = [string]$cfg.Paths.LogRoot
    }

    $scriptPath = $script:RaynetPackageScript
    if ([string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptPath = $MyInvocation.ScriptName
    }

    $scriptBaseName = $null
    if (-not [string]::IsNullOrWhiteSpace($scriptPath)) {
        $scriptBaseName = [System.IO.Path]::GetFileNameWithoutExtension($scriptPath)
    }
    if ([string]::IsNullOrWhiteSpace($scriptBaseName)) {
        $scriptBaseName = $AppName
    }
$safeScriptName = ConvertTo-RaynetSafePathName -Name $scriptBaseName
    $safeAction = ConvertTo-RaynetSafePathName -Name $Action

    # Main package log stays directly in LogRoot.
    $log = Join-Path $LogRoot ("{0}_{1}.log" -f $safeScriptName, $safeAction)

    # Detail/component logs go into one sanitized subfolder per main script.
    $detailFolderName = ConvertTo-RaynetSafePathName -Name ("{0}_Details" -f $safeScriptName)
    $detailLogRoot = Join-Path $LogRoot $detailFolderName
$key = Join-Path $DetectionRoot $AppName

    $reboot = $false
    $exitCode = 1
    $nonCriticalFailures = [System.Collections.Generic.List[string]]::new()
    $successCount = 0
    $alreadyCount = 0
    $failedCount = 0

    function Set-RaynetDetectionState {
        param(
            [Parameter(Mandatory)][string]$Status,
            [Parameter(Mandatory)][int]$Code
        )

        if (-not (Test-Path $DetectionRoot)) {
            New-Item $DetectionRoot -Force | Out-Null
        }
        if (-not (Test-Path $key)) {
            New-Item $key -Force | Out-Null
        }

        $values = @(
            @('InstallDate', (Get-Date).ToString('o'), 'String'),
            @('AppName', $AppName, 'String'),
            @('AppVersion', $AppVersion, 'String'),
            @('PackageRevision', $PackageRevision, 'String'),
            @('LastAction', $Action, 'String'),
            @('LastInstallStatus', $Status, 'String'),
            @('LastExitCode', $Code, 'DWord')
        )

        foreach ($value in $values) {
            New-ItemProperty `
                -Path $key `
                -Name $value[0] `
                -Value $value[1] `
                -PropertyType $value[2] `
                -Force | Out-Null
        }
    }

    try {
        Write-RaynetPackageHeader `
            -LogFile $log `
            -Action $Action `
            -ScriptPath $scriptPath `
            -AppName $AppName `
            -AppVersion $AppVersion `
            -PackageRevision $PackageRevision

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "Package execution initialized." `
            -Level INFO

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "Detail/component logs folder: [$detailLogRoot]." `
            -Level INFO

        $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
        $principal = New-Object Security.Principal.WindowsPrincipal($identity)
        if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
            throw 'Administrative privileges are required.'
        }

        if (-not $Components.Count) {
            throw 'No components defined.'
        }

        for ($index = 0; $index -lt $Components.Count; $index++) {
            $Components[$index] = ConvertTo-RaynetComponent -Component $Components[$index]
            if ($script:RaynetPackageRoot) {
                $Components[$index]['_PackageRoot'] = $script:RaynetPackageRoot
            }
        }

        if ($Action -eq 'Install') {
            $executionList = @($Components)
        }
        else {
            $executionList = @($Components)
            [array]::Reverse($executionList)
        }

        foreach ($component in $executionList) {
            if ($component.Opt_Action -eq 'Default') {
                $effectiveAction = $Action
            }
            else {
                $effectiveAction = $component.Opt_Action
            }

            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "Running component [$($component.Name)] ($($component.Type)). PackageAction=[$Action], EffectiveAction=[$effectiveAction], Critical=[$($component.Opt_Critical)]." `
                -Level INFO

            $result = Invoke-RaynetComponent `
                -Component $component `
                -Action $effectiveAction `
                -LogRoot $detailLogRoot

            if ($result.RebootRequired -or ($result.ExitCode -in $component.RebootExitCodes)) {
                $reboot = $true
            }

            if ($result.Success) {
                $successCount++
                if ($result.AlreadyInDesiredState) {
                    $alreadyCount++
                }

                Write-RaynetInstallerLog `
                    -LogFile $log `
                    -Message "Component result [$($component.Name)]: $($result.Summary)" `
                    -Level SUCCESS
            }
            else {
                $failedCount++
                if ($component.Opt_Critical) {
                    Write-RaynetInstallerLog `
                        -LogFile $log `
                        -Message "Critical component [$($component.Name)] failed: $($result.Summary)" `
                        -Level ERROR
                    throw "Component [$($component.Name)] failed."
                }

                $nonCriticalFailures.Add($component.Name)
                Write-RaynetInstallerLog `
                    -LogFile $log `
                    -Message "Non-critical component [$($component.Name)] failed; continuing. $($result.Summary)" `
                    -Level WARNING
            }
        }

        if ($Action -eq 'Install') {
            if (-not (Test-RaynetAllComponentsInstalled -Components $Components -PackageAction $Action)) {
                throw 'Post-install detection verification failed.'
            }

            if ($reboot) {
                $exitCode = 3010
                $status = 'Success-RebootRequired'
            }
            else {
                $exitCode = 0
                $status = 'Success'
            }

            Set-RaynetDetectionState -Status $status -Code $exitCode
        }
        else {
            if (Test-Path $key) {
                Remove-Item $key -Recurse -Force -ErrorAction Stop
            }

            if ($reboot) {
                $exitCode = 3010
            }
            else {
                $exitCode = 0
            }
        }

        if ($nonCriticalFailures.Count -gt 0) {
            $finalMessage = 'Package completed successfully with warnings.'
            $finalLevel = 'WARNING'
        }
        else {
            $finalMessage = 'Package completed successfully.'
            $finalLevel = 'SUCCESS'
        }

        Write-RaynetInstallerLog -LogFile $log -Message $finalMessage -Level $finalLevel
        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "Summary: Components=[$($executionList.Count)] Successful=[$successCount] AlreadySatisfied=[$alreadyCount] Failed=[$failedCount] NonCriticalFailures=[$($nonCriticalFailures.Count)] RebootRequired=[$reboot] ExitCode=[$exitCode]." `
            -Level INFO

        foreach ($failedName in $nonCriticalFailures) {
            Write-RaynetInstallerLog `
                -LogFile $log `
                -Message "Warning component: [$failedName]." `
                -Level WARNING
        }
    }
    catch {
        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message "Package failed: $($_.Exception.Message)" `
            -Level ERROR

        Write-RaynetInstallerLog `
            -LogFile $log `
            -Message $_.Exception.ToString() `
            -Level DEBUG

        try {
            Set-RaynetDetectionState -Status 'Failed' -Code 1
        }
        catch {
        }
        $exitCode = 1
    }

    return [pscustomobject]@{
        Success             = ($exitCode -in @(0, 3010))
        ExitCode            = $exitCode
        RebootRequired      = $reboot
        NonCriticalFailures = @($nonCriticalFailures)
    }
}
