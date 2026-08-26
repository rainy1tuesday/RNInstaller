# Raynet Installer Framework 0.4 — DeleteDirectory

Added the self-contained `Raynet_DeleteDirectory` component.

Example:

```powershell
Raynet_DeleteDirectory `
    -Name "Remove old application directory" `
    -Path "C:\Program Files\OldApp"
```

Defaults:
- Opt_Recurse = true
- Opt_Force = true
- Opt_Verify = true
- Opt_Action = Default
- Opt_Critical = true
- Opt_TimeoutSeconds = 0

A missing target directory is treated as success / already in desired state.
