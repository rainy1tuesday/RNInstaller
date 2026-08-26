# Raynet Installer Framework 0.4 — MSI consolidation

The MSI component is now fully self-contained in:

`Components\Raynet_MSI.ps1`

It contains:
- `Raynet_MSI`
- `Invoke-RaynetMSI`
- `Raynet_TestMSIInstalled`

The obsolete `Private\MSI` folder has been removed.
No other framework behavior was intentionally changed.
