# Module tests

The test suite uses Pester 5 and covers module import and exports, component
registration, normalization and validation, safe component names, and dispatch.
These tests avoid Windows registry, service, and installer operations, so they
can run on Windows or PowerShell 7 on other platforms.

Run from the repository root:

```powershell
Invoke-Pester -Path ./Modules/Raynet.InstallerModule/Tests
```

Install Pester 5 if it is not already available:

```powershell
Install-Module Pester -MinimumVersion 5.0 -Scope CurrentUser
```
