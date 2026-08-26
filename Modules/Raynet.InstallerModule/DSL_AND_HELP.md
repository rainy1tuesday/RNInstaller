# Raynet DSL and built-in help

The package script now defines components using PowerShell commands rather than hashtables.
Commands add component definitions to the current package; they do not execute the operation immediately.

Example:

```powershell
Raynet_MSI -Name 'Install MyApp' -MsiPath 'Files\MyApp.msi'
Raynet_CopyFile -Name 'Copy config' -SourceFile 'Files\app.config' -TargetFile 'C:\ProgramData\MyApp\app.config'
Raynet_DeleteFiles -Name 'Remove legacy files' -TargetFolder 'C:\ProgramData\OldApp' -Opt_Action Uninstall
```

## Component action

`-Opt_Action` accepts:

- `Default` — use the package action (`Install` or `Uninstall`).
- `Install` — run this component's install operation regardless of package action.
- `Uninstall` — run this component's uninstall operation regardless of package action.

The effective action is written to the package log.

## Help

From the package directory:

```powershell
.\Remove NIAgent.ps1 -Help
.\Remove NIAgent.ps1 -Help Raynet_MSI
.\Remove NIAgent.ps1 -Help Raynet_CopyFile
```

Inside PowerShell the same information is available with:

```powershell
Get-Help Raynet_MSI -Full
Get-Help Raynet_MSI -Examples
Get-Help Raynet_MSI -Parameter Opt_Action
```

The component functions use PowerShell parameter validation, so invalid enum values are rejected before the package runs.


## Important action semantics

`Opt_Action` controls whether a component is invoked; it does not rename the operation implemented by the component.
For example, `Raynet_DeleteFiles` is inherently a deletion operation, but `-Opt_Action Uninstall` means it is only invoked during package uninstall.

For mixed-action packages, post-install MSI detection ignores components whose effective action is `Uninstall`, so an intentional uninstall component does not make the package appear to have failed installation detection.
