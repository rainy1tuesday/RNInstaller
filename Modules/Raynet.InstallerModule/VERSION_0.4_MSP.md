# Raynet Installer Framework 0.4 — MSP component

Added `Raynet_MSP` as a single-file component under `Components\Raynet_MSP.ps1`.

Public options:

- Name
- FileName
- Opt_Arguments
- Opt_PatchCode
- Opt_ProductCode
- Opt_Action
- Opt_Critical
- Opt_Verify
- Opt_Force
- Opt_TimeoutSeconds
- Opt_SuccessExitCodes
- Opt_RebootExitCodes
- Opt_LogMSI

Typical use:

```powershell
Raynet_MSP `
    -Name "Patch My Application" `
    -FileName "Files\MyPatch.msp"
```

The component attempts to read the patch GUID from the MSP automatically and
uses Windows Installer registration for idempotent detection and uninstall.

For unusual patches or deterministic uninstall, `Opt_PatchCode` and
`Opt_ProductCode` may be supplied explicitly.
