function Test-RaynetAllComponentsInstalled {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][array]$Components,
        [Parameter(Mandatory=$true)][ValidateSet('Install','Uninstall')][string]$PackageAction
    )
    foreach($Component in $Components){
        $effective=if($Component.Opt_Action -eq 'Default'){$PackageAction}else{$Component.Opt_Action}
        if($effective -ne 'Install' -or -not $Component.Enabled){ continue }
        switch($Component.Type){
            'MSI' { if(-not (Raynet_TestMSIInstalled $Component.ProductCode)){ return $false } }
            'MSP' {
                $patchCode = [string]$Component.Opt_PatchCode
                if ([string]::IsNullOrWhiteSpace($patchCode) -and (Test-Path -LiteralPath $Component.FileName -PathType Leaf)) {
                    $patchCode = Get-RaynetMSPPatchCode -FileName $Component.FileName
                }
                if ([string]::IsNullOrWhiteSpace($patchCode)) { return $false }

                $productCode = [string]$Component.Opt_ProductCode
                if (-not (Raynet_TestMSPInstalled -PatchCode $patchCode -ProductCode $productCode)) {
                    return $false
                }
            }
        }
    }
    return $true
}
