BeforeAll {
    $moduleRoot = Split-Path -Parent $PSScriptRoot
    Import-Module -Name (Join-Path $moduleRoot 'Raynet.InstallerModule.psm1') -Force
}

Describe 'Raynet.InstallerModule public surface' {
    It 'imports and exports the package and component DSL' {
        $commands = Get-Command -Name @(
            'Initialize-RaynetPackage',
            'Add-RaynetComponent',
            'Get-RaynetComponents',
            'Invoke-RaynetPackage',
            'Raynet_CopyFiles'
        ) -Module 'Raynet.InstallerModule'

        $commands.Count | Should -Be 5
    }

    It 'resolves registered component types to their implementations' {
        $handlerNames = InModuleScope 'Raynet.InstallerModule' {
            @('CopyFile', 'EXE', 'MSI', 'MSP') | ForEach-Object {
                (Resolve-RaynetComponentCommand -Type $_).Name
            }
        }

        $handlerNames | Should -Be @(
            'Invoke-RaynetCopyFile',
            'Invoke-RaynetEXE',
            'Invoke-RaynetMSI',
            'Invoke-RaynetMSP'
        )
    }

    It 'passes the framework self-test with aliases and helper functions' {
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
        $components[0].SourceFile | Should -Match '[\\/]config\.ini$'
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
        $component = InModuleScope 'Raynet.InstallerModule' {
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
        $component = InModuleScope 'Raynet.InstallerModule' {
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
        InModuleScope 'Raynet.InstallerModule' {
            {
                ConvertTo-RaynetComponent -Component @{ Name = 'Missing type' }
            } | Should -Throw '*Type is required*'

            {
                ConvertTo-RaynetComponent -Component @{ Type = 'EXE'; Name = 'Missing path' }
            } | Should -Throw '*ExePath*is required*'
        }
    }

    It 'rejects a negative timeout' {
        InModuleScope 'Raynet.InstallerModule' {
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
        $safeName = InModuleScope 'Raynet.InstallerModule' {
            ConvertTo-RaynetSafePathName -Name 'folder/name.  '
        }

        $safeName | Should -Be 'folder_name'
    }

    It 'protects reserved DOS device names' {
        $safeName = InModuleScope 'Raynet.InstallerModule' {
            ConvertTo-RaynetSafePathName -Name 'CON.txt'
        }

        $safeName | Should -Be '_CON.txt'
    }
}

Describe 'Component dispatch' {
    It 'dispatches to the implementation matching the component type' {
        $result = InModuleScope 'Raynet.InstallerModule' {
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
        InModuleScope 'Raynet.InstallerModule' {
            {
                Invoke-RaynetComponent `
                    -Component @{ Type = 'DoesNotExist' } `
                    -LogRoot 'test-logs' `
                    -Action Install
            } | Should -Throw '*No*implementation*DoesNotExist*'
        }
    }

}

Describe 'INI component execution' {
    It 'updates the INI and returns the standard result while logging the action' {
        $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "RaynetIni-$([guid]::NewGuid())"
        $iniPath = Join-Path $testRoot 'app.ini'
        $logRoot = Join-Path $testRoot 'logs'
        $null = New-Item -Path $testRoot -ItemType Directory -Force

        try {
            Set-Content -LiteralPath $iniPath -Value @('[General]', 'Language=en')
            $result = InModuleScope 'Raynet.InstallerModule' -Parameters @{
                Component = @{
                    Name = 'Configure language'
                    IniFile = $iniPath
                    Entries = @(@{ Section = 'General'; Key = 'Language'; Value = 'fr' })
                }
                LogRoot = $logRoot
            } {
                param($Component, $LogRoot)
                Invoke-RaynetModifyIni -Component $Component -LogRoot $LogRoot -Action Install
            }

            $result.Success | Should -BeTrue
            $result.Summary | Should -Match 'updated successfully'
            (Get-Content -LiteralPath $iniPath -Raw) | Should -Match 'Language=fr'
            Test-Path -LiteralPath (Join-Path $logRoot 'Configure language_Install.log') | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'EXE component validation' {
    It 'fails clearly when the selected executable does not exist' {
        $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "RaynetExe-$([guid]::NewGuid())"

        try {
            $result = InModuleScope 'Raynet.InstallerModule' -Parameters @{
                LogRoot = $testRoot
            } {
                param($LogRoot)
                Invoke-RaynetEXE `
                    -Component @{
                        Name = 'Missing executable'
                        ExePath = (Join-Path $LogRoot 'missing.exe')
                    } `
                    -LogRoot $LogRoot `
                    -Action Install
            }

            $result.Success | Should -BeFalse
            $result.Error | Should -Match 'Executable not found'
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Registry component execution' {
    It 'supports Remove and uses the effective action in its log filename' {
        $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "RaynetRegistry-$([guid]::NewGuid())"

        try {
            $result = InModuleScope 'Raynet.InstallerModule' -Parameters @{
                LogRoot = $testRoot
            } {
                param($LogRoot)
                Mock Test-Path { $false } -ParameterFilter {
                    $LiteralPath -like 'HKCU:*'
                }

                Invoke-RaynetRegModify `
                    -Component @{
                        Name = 'Remove missing value'
                        RegistryPath = 'HKCU:\Software\RaynetTest'
                        ValueName = 'Missing'
                        RegistryAction = 'Remove'
                    } `
                    -LogRoot $LogRoot `
                    -Action Uninstall
            }

            $result.Success | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $testRoot 'Remove missing value_Uninstall.log') | Should -BeTrue
            Test-Path -LiteralPath (Join-Path $testRoot 'Remove missing value_RegModify.log') | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'SQL database component credentials' {
    It 'keeps the SQL password out of sqlcmd arguments and restores the environment' {
        $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "RaynetSql-$([guid]::NewGuid())"
        $sqlPath = Join-Path $testRoot 'attach.sql'
        $logRoot = Join-Path $testRoot 'logs'
        $previousProgramFiles = $env:ProgramFiles
        $previousSqlCmdPassword = $env:SQLCMDPASSWORD
        $secureTestPassword = [securestring]::new()
        foreach ($character in 'test-value'.ToCharArray()) {
            $secureTestPassword.AppendChar($character)
        }
        $secureTestPassword.MakeReadOnly()
        $null = New-Item -Path $logRoot -ItemType Directory -Force
        Set-Content -LiteralPath $sqlPath -Value 'PRINT 1'
        $env:ProgramFiles = $testRoot

        try {
            $execution = InModuleScope 'Raynet.InstallerModule' -Parameters @{
                SqlPath = $sqlPath
                LogRoot = $logRoot
                Password = $secureTestPassword
            } {
                param($SqlPath, $LogRoot, $Password)
                Mock Test-Path { $true }
                Mock Start-Process {
                    $script:capturedSqlCmdArguments = $ArgumentList
                    $script:capturedSqlCmdPassword = $env:SQLCMDPASSWORD
                    [pscustomobject]@{ ExitCode = 0 }
                }

                $result = Invoke-RaynetAttachSqlDatabase `
                    -Component @{
                        Name = 'Attach database'
                        SqlFile = $SqlPath
                        SqlServer = 'localhost'
                        SqlUser = 'installer'
                        SqlPassword = $Password
                    } `
                    -LogRoot $LogRoot `
                    -Action Install

                [pscustomobject]@{
                    Result = $result
                    Arguments = $script:capturedSqlCmdArguments
                    PasswordDuringExecution = $script:capturedSqlCmdPassword
                    PasswordAfterExecution = $env:SQLCMDPASSWORD
                }
            }

            $execution.Result.Success | Should -BeTrue
            (@($execution.Arguments) -join ' ') | Should -Not -Match 'test-value'
            $execution.PasswordDuringExecution | Should -Be 'test-value'
            $execution.PasswordAfterExecution | Should -BeNullOrEmpty
        }
        finally {
            if ($null -eq $previousProgramFiles) {
                Remove-Item Env:ProgramFiles -ErrorAction SilentlyContinue
            }
            else {
                $env:ProgramFiles = $previousProgramFiles
            }

            if ($null -eq $previousSqlCmdPassword) {
                Remove-Item Env:SQLCMDPASSWORD -ErrorAction SilentlyContinue
            }
            else {
                $env:SQLCMDPASSWORD = $previousSqlCmdPassword
            }
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Service configuration credentials' {
    It 'passes the configured account password to the service API without logging it' {
        $testRoot = Join-Path ([System.IO.Path]::GetTempPath()) "RaynetService-$([guid]::NewGuid())"
        $logRoot = Join-Path $testRoot 'logs'
        $secureTestPassword = [securestring]::new()
        foreach ($character in 'test-value'.ToCharArray()) {
            $secureTestPassword.AppendChar($character)
        }
        $secureTestPassword.MakeReadOnly()

        try {
            $execution = InModuleScope 'Raynet.InstallerModule' -Parameters @{
                LogRoot = $logRoot
                Password = $secureTestPassword
            } {
                param($LogRoot, $Password)
                function Get-Service { }
                function Get-CimInstance { }
                function Invoke-CimMethod {
                    param($InputObject, $MethodName, $Arguments)
                }
                Mock Get-Service { [pscustomobject]@{ Status = 'Stopped' } }
                Mock Get-CimInstance { [pscustomobject]@{ Name = 'ExampleService' } }
                Mock Write-RaynetInstallerLog {
                    if ($Message -match 'test-value') {
                        throw 'The service password must not be written to a log.'
                    }
                }
                Mock Invoke-CimMethod {
                    param($InputObject, $MethodName, $Arguments)
                    if ($Arguments.StartPassword -ne 'test-value') {
                        throw 'Configured service password was not passed to the service API.'
                    }
                    [pscustomobject]@{ ReturnValue = 0 }
                }

                Invoke-RaynetConfigureService `
                    -Component @{
                        ServiceName = 'ExampleService'
                        Opt_Configure_AccountName = 'DOMAIN\service'
                        Opt_Configure_Password = $Password
                    } `
                    -LogRoot $LogRoot `
                    -Action Install
            }

            $execution.Success | Should -BeTrue
        }
        finally {
            Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
        }
    }
}

Describe 'Module configuration' {
    It 'reads configuration values and converts boolean settings' {
        $configPath = Join-Path ([System.IO.Path]::GetTempPath()) "RaynetInstaller-$([guid]::NewGuid()).ini"

        try {
            @(
                '[Logging]'
                'Level=DEBUG'
                'ComponentLogs=false'
            ) | Set-Content -LiteralPath $configPath

            $config = InModuleScope 'Raynet.InstallerModule' -Parameters @{
                Path = $configPath
            } {
                param($Path)
                Get-RaynetConfiguration -ConfigPath $Path
            }

            $config.Logging.Level | Should -Be 'DEBUG'
            $config.Logging.ComponentLogs | Should -BeFalse
        }
        finally {
            Remove-Item -LiteralPath $configPath -Force -ErrorAction SilentlyContinue
        }
    }
}
