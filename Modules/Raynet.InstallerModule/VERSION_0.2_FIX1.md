# Raynet Installer Framework 0.2 First Shot — Fix 1

Fixed module loading for root-level `Private` helpers.

`Raynet.Configuration.ps1` and other helpers stored directly in `Private\`
are now dot-sourced before components and public functions are loaded.

This fixes:
`The term 'Get-RaynetConfiguration' is not recognized ...`
