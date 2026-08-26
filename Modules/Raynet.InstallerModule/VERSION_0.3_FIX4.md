# Raynet Installer Framework 0.3 First Shot — Fix 4

Help interface updated on top of the working Fix 3 baseline.

- `-Help` is now a switch.
- `-HelpComponent <Raynet_Function>` shows detailed help.
- Both help modes exit before package initialization/execution.
- General help dynamically lists available `Raynet_*` functions and their synopsis.

Examples:

```powershell
.\Remove NIAgent.ps1 -Help
.\Remove NIAgent.ps1 -HelpComponent Raynet_MSI
```
