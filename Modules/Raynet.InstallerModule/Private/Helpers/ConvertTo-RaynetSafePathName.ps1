<#
.SYNOPSIS
    Converts text into a Windows-safe file or directory name.

.DESCRIPTION
    Replaces invalid Windows filename characters and control characters with
    underscores, trims trailing spaces/periods, and protects reserved DOS names.

.PARAMETER Name
    Input text to sanitize.

.NOTES
    Raynet Installer Framework 0.4.
#>
function ConvertTo-RaynetSafePathName {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory)]
        [AllowEmptyString()]
        [string]$Name
    )

    $safe = $Name

    foreach ($char in [System.IO.Path]::GetInvalidFileNameChars()) {
        $safe = $safe.Replace([string]$char, '_')
    }

    $safe = $safe -replace '[\\/]+', '_'
    $safe = $safe.Trim().TrimEnd('.', ' ')

    if ([string]::IsNullOrWhiteSpace($safe)) {
        $safe = '_'
    }

    if ($safe -match '^(?i:CON|PRN|AUX|NUL|COM[1-9]|LPT[1-9])(?:\..*)?$') {
        $safe = "_$safe"
    }

    return $safe
}
