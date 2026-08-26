# Raynet Installer Framework 0.4 — Fix 5: Windows Installer defaults

Framework policy for all Windows Installer operations:

- MSI install: `/qn /norestart`
- MSI uninstall: `/qn /norestart`
- MSP install/patch: `/qn /norestart`
- MSP uninstall: `/qn /norestart`

These switches are framework-controlled defaults and do not need to be specified
in package scripts. Additional `Opt_Arguments` remain supported.
