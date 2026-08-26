# Native PowerShell help and discovery

Raynet 0.4 uses PowerShell-native help/discovery only.

```powershell
Import-Module .\Modules\Raynet.InstallerModule\Raynet.InstallerModule.psm1 -Force

Get-Command Raynet_*
Get-Command -Module Raynet.InstallerModule
Get-Help Raynet_MSI
Get-Help Raynet_MSI -Full
Get-Help Raynet_MSI -Examples
Get-Help Raynet_MSI -Parameter Opt_Critical
```

The main package script no longer contains `-Help` or `-HelpComponent`.
VS Code IntelliSense should derive suggestions from the actual `param()` blocks.
The deprecated `Raynet_CopyFile` compatibility wrapper was removed; use `Raynet_CopyFiles`.
