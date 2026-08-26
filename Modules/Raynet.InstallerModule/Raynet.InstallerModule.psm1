# Raynet.InstallerModule.psm1 - Framework 0.4
# Raynet framework root initialization
$script:RaynetModuleRoot = $PSScriptRoot
$script:RaynetRoot       = $PSScriptRoot
$raynetRoot              = $script:RaynetModuleRoot
foreach ($folder in @('Private','Private\Helpers','Private\Logging','Private\Detection')) {
    $path = Join-Path $raynetRoot $folder
    if (Test-Path -LiteralPath $path) {
        Get-ChildItem -LiteralPath $path -Filter '*.ps1' -File -ErrorAction SilentlyContinue |
            Sort-Object FullName |
            ForEach-Object { . $_.FullName }
    }
}

$componentRoot = Join-Path $raynetRoot 'Components'
if (Test-Path -LiteralPath $componentRoot) {
    Get-ChildItem -LiteralPath $componentRoot -Filter '*.ps1' -File -Recurse |
        Sort-Object FullName |
        ForEach-Object { . $_.FullName }
}

$publicRoot = Join-Path $raynetRoot 'Public'
if (Test-Path -LiteralPath $publicRoot) {
    Get-ChildItem -LiteralPath $publicRoot -Filter '*.ps1' -File -Recurse |
        Where-Object { $_.FullName -notmatch '\\Config\\' } |
        Sort-Object FullName |
        ForEach-Object { . $_.FullName }
}

$pluginRoot = Join-Path $raynetRoot 'Plugins'
if (Test-Path -LiteralPath $pluginRoot) {
    Get-ChildItem -LiteralPath $pluginRoot -File -Recurse |
        Where-Object { $_.Extension -in '.ps1','.psm1' } |
        Sort-Object FullName |
        ForEach-Object {
            if ($_.Extension -eq '.psm1') {
                Import-Module $_.FullName -Force -ErrorAction Stop
            } else {
                . $_.FullName
            }
        }
}

$publicFunctions = @(
    'Initialize-RaynetPackage',
    'Add-RaynetComponent',
    'Get-RaynetComponents',
    'Invoke-RaynetPackage',

    'Test-RaynetFramework'
)

$componentFunctions = Get-Command -CommandType Function |
    Where-Object { $_.Name -like 'Raynet_*' } |
    Select-Object -ExpandProperty Name -Unique

$exports = @($publicFunctions + $componentFunctions) |
    Where-Object { Get-Command $_ -CommandType Function -ErrorAction SilentlyContinue } |
    Select-Object -Unique

if ($exports) {
    Export-ModuleMember -Function $exports
}
