# Raynet Installer Framework 0.4 — Native Help / IntelliSense Audit

- Removed custom `-Help` / `-HelpComponent`.
- Removed `Invoke-RaynetPackageHelp` and `Get-RaynetHelp`.
- Standardized on native `Get-Help` and `Get-Command`.
- Removed the deprecated `Raynet_CopyFile` compatibility wrapper.
- Audited public `Raynet_*` signatures for ambiguous parameter patterns.
- Cleaned the main template's duplicated parameter block.
- Existing component execution behavior was not intentionally changed.
