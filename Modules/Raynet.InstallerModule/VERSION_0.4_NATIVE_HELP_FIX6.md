# Raynet Installer Framework 0.4 — Fix 6: MSI quiet-mode correction

Fix 5 documented `/qn /norestart` but did not modify the actual argument
construction used by `Invoke-RaynetMSI`.

Fix 6 patches the real MSI argument list so MSI install and uninstall include:

- `/qn`
- `/norestart`

MSP already used both switches correctly.
