# Raynet Installer Framework 0.4 — Native Help Fix 2

Fixed log-directory creation.

Before any package header or regular log message is written, the parent directory
of the target log file is now created automatically with `New-Item -Force`.

This fixes failures such as:

`Could not find a part of the path '...\Logs\<Package>\<Package>_Install.log'`

The central logger contains the same safeguard, so component log directories are
also created on demand.
