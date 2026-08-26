# Raynet Installer Framework 0.4 — CopyFiles cleanup

The accidental double-s spelling of the CopyFiles command has been removed.

The current file-copy DSL command is:

`Raynet_CopyFiles`

The legacy singular `Raynet_CopyFile` compatibility wrapper is retained and
continues to forward to `Raynet_CopyFiles`.
