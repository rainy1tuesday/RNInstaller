$moduleRoot = Split-Path -Parent $PSScriptRoot
$modulePath = Join-Path $moduleRoot 'Raynet.InstallerModule.psm1'
$moduleName = 'Raynet.InstallerModule'

BeforeAll {
    Import-Module -Name $modulePath -Force
}

Describe 'Raynet.InstallerModule public surface' {
    It 'imports and exports the package and component DSL' {
        Get-Command -Name Initialize-RaynetPackage, Add-RaynetComponent, Get-RaynetComponents,
            Invoke-RaynetPackage, Raynet_CopyFiles -Module $moduleName |
            Select-Object -ExpandProperty Name |
            Should -Contain 'Raynet_CopyFiles'
    }

    It 'passes the framework component convention self-test' {
        Test-RaynetFramework | Should -BeTrue
    }
}

Describe 'Package component registration' {
    BeforeEach {
        Initialize-RaynetPackage -Action Install
    }

    It 'starts a package with no registered components' {
        @(Get-RaynetComponents).Count | Should -Be 0
    }

    It 'registers components through the public DSL' {
        Raynet_CopyFiles -Name 'Copy config' -SourceFile 'config.ini' -TargetFile 'out/config.ini'

        $components = @(Get-RaynetComponents)
        $components.Count | Should -Be 1
        $components[0].Type | Should -Be 'CopyFile'
        $components[0].SourceFile | Should -Be 'config.ini'
        $components[0].TargetFile | Should -Be 'out/config.ini'
    }

    It 'resets registered components when a new package is initialized' {
        Add-RaynetComponent -Component @{ Type = 'Example'; Name = 'First' }
        Initialize-RaynetPackage -Action Uninstall

        @(Get-RaynetComponents).Count | Should -Be 0
    }
}

Describe 'Component normalization and validation' {
    It 'adds framework defaults to a valid component' {
        $component = InModuleScope $moduleName {
            ConvertTo-RaynetComponent -Component @{
                Type = 'EXE'
                Name = 'Example'
                ExePath = 'example.exe'
            }
        }

        $component.Opt_Action | Should -Be 'Default'
        $component.Opt_Critical | Should -BeTrue
        $component.TimeoutSeconds | Should -Be 0
        $component.Verify | Should -BeTrue
    }

    It 'normalizes legacy option names without replacing canonical values' {
        $component = InModuleScope $moduleName {
            ConvertTo-RaynetComponent -Component @{
                Type = 'EXE'
                Name = 'Example'
                ExePath = 'example.exe'
                Opt_TimeoutSeconds = 30
                TimeoutSeconds = 60
                Opt_SuccessExitCodes = @(5)
            }
        }

        $component.TimeoutSeconds | Should -Be 60
        $component.SuccessCodes | Should -Be @(5)
    }

    It 'rejects components missing their type or required properties' {
        InModuleScope $moduleName {
            {
                ConvertTo-RaynetComponent -Component @{ Name = 'Missing type' }
            } | Should -Throw '*Type is required*'

            {
                ConvertTo-RaynetComponent -Component @{ Type = 'EXE'; Name = 'Missing path' }
            } | Should -Throw '*ExePath*is required*'
        }
    }

    It 'rejects a negative timeout' {
        InModuleScope $moduleName {
            {
                ConvertTo-RaynetComponent -Component @{
                    Type = 'EXE'
                    Name = 'Example'
                    ExePath = 'example.exe'
                    TimeoutSeconds = -1
                }
            } | Should -Throw '*TimeoutSeconds cannot be negative*'
        }
    }
}

Describe 'Safe component names' {
    It 'replaces path separators and trims trailing periods and spaces' {
        $safeName = InModuleScope $moduleName {
            ConvertTo-RaynetSafePathName -Name 'folder/name.  '
        }

        $safeName | Should -Be 'folder_name'
    }

    It 'protects reserved DOS device names' {
        $safeName = InModuleScope $moduleName {
            ConvertTo-RaynetSafePathName -Name 'CON.txt'
        }

        $safeName | Should -Be '_CON.txt'
    }
}

Describe 'Component dispatch' {
    It 'dispatches to the implementation matching the component type' {
        $result = InModuleScope $moduleName {
            function Invoke-RaynetTest {
                param(
                    [hashtable]$Component,
                    [string]$LogRoot,
                    [string]$Action
                )

                [pscustomobject]@{
                    Type = $Component.Type
                    LogRoot = $LogRoot
                    Action = $Action
                }
            }

            Invoke-RaynetComponent `
                -Component @{ Type = 'Test' } `
                -LogRoot 'test-logs' `
                -Action Install
        }

        $result.Type | Should -Be 'Test'
        $result.LogRoot | Should -Be 'test-logs'
        $result.Action | Should -Be 'Install'
    }

    It 'reports an unknown component type' {
        InModuleScope $moduleName {
            {
                Invoke-RaynetComponent `
                    -Component @{ Type = 'DoesNotExist' } `
                    -LogRoot 'test-logs' `
                    -Action Install
            } | Should -Throw '*No*implementation*DoesNotExist*'
        }
    }
}
