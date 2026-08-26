function Test-RaynetPathAccess {
    <# Non-destructive diagnostics for files/directories, including UNC/network paths. #>
    param(
        [Parameter(Mandatory)][string]$Path,
        [ValidateSet('Read','Write','ReadWrite')][string]$Mode='Read',
        [string]$LogFile,
        [string]$Label='Path'
    )
    $result=[ordered]@{ Path=$Path; Exists=$false; IsDirectory=$false; Readable=$false; Writable=$false; Accessible=$false; IsNetworkPath=($Path -match '^\\\\'); Error=$null }
    try {
        $item=Get-Item -LiteralPath $Path -Force -ErrorAction Stop
        $result.Exists=$true; $result.IsDirectory=$item.PSIsContainer
        $result.Accessible=$true
        if ($item.PSIsContainer) {
            Get-ChildItem -LiteralPath $Path -Force -ErrorAction Stop | Select-Object -First 1 | Out-Null
            $result.Readable=$true
            if ($Mode -in @('Write','ReadWrite')) {
                $probe=Join-Path $Path ('.raynet_write_test_{0}.tmp' -f ([guid]::NewGuid().ToString('N')))
                try { [IO.File]::WriteAllText($probe,'Raynet write access test'); $result.Writable=$true }
                finally { Remove-Item -LiteralPath $probe -Force -ErrorAction SilentlyContinue }
            }
        } else {
            try { $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::Read,[IO.FileShare]::ReadWrite); $fs.Dispose(); $result.Readable=$true } catch { $result.ReadError=$_.Exception.Message }
            if ($Mode -in @('Write','ReadWrite')) {
                try { $fs=[IO.File]::Open($Path,[IO.FileMode]::Open,[IO.FileAccess]::ReadWrite,[IO.FileShare]::ReadWrite); $fs.Dispose(); $result.Writable=$true } catch { $result.WriteError=$_.Exception.Message }
            }
        }
    } catch { $result.Error=$_.Exception.Message }
    if ($LogFile) {
        $level=if($result.Error -or (($Mode -eq 'Read' -and -not $result.Readable)) -or (($Mode -eq 'Write' -and -not $result.Writable)) -or (($Mode -eq 'ReadWrite' -and (-not $result.Readable -or -not $result.Writable)))){'WARNING'}else{'DEBUG'}
        Write-RaynetInstallerLog -LogFile $LogFile -Level $level -Message ("{0}: Path=[{1}] Network=[{2}] Exists=[{3}] Directory=[{4}] Readable=[{5}] Writable=[{6}] Accessible=[{7}] Error=[{8}]" -f $Label,$Path,$result.IsNetworkPath,$result.Exists,$result.IsDirectory,$result.Readable,$result.Writable,$result.Accessible,$result.Error)
        if($result.ReadError){Write-RaynetInstallerLog -LogFile $LogFile -Level WARNING -Message "${Label}: Read test error: $($result.ReadError)"}
        if($result.WriteError){Write-RaynetInstallerLog -LogFile $LogFile -Level WARNING -Message "${Label}: Write test error: $($result.WriteError)"}
    }
    [pscustomobject]$result
}
