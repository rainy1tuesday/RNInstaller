<#
.SYNOPSIS
    Checks the Raynet 0.4 single-file component convention.
#>
function Test-RaynetFramework {
    [CmdletBinding()]
    param()

    $errors = [System.Collections.Generic.List[string]]::new()
    $files = Get-ChildItem -LiteralPath (Join-Path $raynetRoot 'Components') -Filter '*.ps1' -File -Recurse
    $functionAliases = @{
        CopyFiles = 'CopyFile'
        TestMSIInstalled = ''
        TestMSPInstalled = ''
    }

    foreach ($file in $files) {
        $content = Get-Content -LiteralPath $file.FullName -Raw
        $functionMatches = [regex]::Matches($content, '(?im)^\s*function\s+Raynet_([A-Za-z0-9_]+)\b')

        foreach ($match in $functionMatches) {
            $suffix = $match.Groups[1].Value
            if ($functionAliases.ContainsKey($suffix)) {
                $suffix = $functionAliases[$suffix]
                if (-not $suffix) {
                    continue
                }
            }

            $invokeName = "Invoke-Raynet$suffix"
            $invoke = Get-Command $invokeName -CommandType Function -ErrorAction SilentlyContinue

            if (-not $invoke) {
                $errors.Add("[$($file.Name)] contains Raynet_$suffix but no $invokeName.")
                continue
            }

            foreach ($parameterName in @('Component','LogRoot','Action')) {
                if (-not $invoke.Parameters.ContainsKey($parameterName)) {
                    $errors.Add("$invokeName is missing parameter -$parameterName.")
                }
            }
        }
    }

    if ($errors.Count -gt 0) {
        $errors | ForEach-Object { Write-Error $_ }
        return $false
    }

    Write-Output 'Raynet framework self-test passed.'
    return $true
}
