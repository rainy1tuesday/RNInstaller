function Set-RaynetShortcutRunAsAdministrator {
    param(
        [string]$ShortcutPath
    )

    $Bytes = [System.IO.File]::ReadAllBytes($ShortcutPath)

    $Bytes[21] = $Bytes[21] -bor 0x20

    [System.IO.File]::WriteAllBytes(
        $ShortcutPath,
        $Bytes
    )
}
