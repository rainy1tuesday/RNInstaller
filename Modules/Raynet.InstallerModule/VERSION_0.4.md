# Raynet Installer Framework 0.4 — First Shot

- One component = one .ps1 in Components.
- Each component file contains Raynet_X and Invoke-RaynetX.
- Dynamic Type X -> Invoke-RaynetX dispatch.
- No central component registration table.
- Help logic moved into Invoke-RaynetPackageHelp.
- Main package script only has help parameters plus one help handoff call.
- Existing 0.3 configuration/logging/path/XML behavior retained.
