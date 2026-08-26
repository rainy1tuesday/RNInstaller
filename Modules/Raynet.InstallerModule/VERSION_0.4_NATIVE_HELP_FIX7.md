# Raynet Installer Framework 0.4 — Fix 7: MSI quiet-mode syntax

Fixes a PowerShell syntax/command-construction bug where `/qn /norestart`
were appended outside the `$args` string.

Correct builders are now:

Install:
`$args="/i `"$($Component.MsiPath)`" /qn /norestart"`

Uninstall:
`$args="/x $($Component.ProductCode) /qn /norestart"`

Additional transform/install/uninstall arguments are appended afterward.
