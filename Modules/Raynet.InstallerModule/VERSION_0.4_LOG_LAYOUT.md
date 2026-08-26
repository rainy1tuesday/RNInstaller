# Raynet Installer Framework 0.4 — Log layout update

New layout for `MyMainScript.ps1`:

`<LogRoot>\MyMainScript_Install.log`

`<LogRoot>\MyMainScript_Details\`
- `<ComponentName>_Install.log`
- `<ComponentName>_Install_MSI.log`
- ...

The main log explicitly records the detail-log folder path.

All generated file and folder names pass through
`ConvertTo-RaynetSafePathName` before use.
