# Raynet Installer Framework 0.4 — Native Help Fix 1

Fixed framework-root initialization.

At module import:
- `$script:RaynetModuleRoot` is initialized to `$PSScriptRoot`
- `$script:RaynetRoot` is initialized to `$PSScriptRoot`
- `$raynetRoot` aliases the same framework root for compatibility

The configuration loader also falls back safely if the script-scoped root is unavailable.

This fixes the Join-Path error caused by a null `$script:RaynetModuleRoot`.
