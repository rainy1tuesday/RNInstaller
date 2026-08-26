# Raynet Installer Framework 0.2

## Configuration
Framework-wide paths are now outside package scripts in `Raynet.Installer.ini`.

- `[Paths] LogRoot`
- `[Paths] DetectionRoot`
- `[Logging] Level`
- `[Framework] CreateMissingDirectories`

Built-in defaults are used if the configuration file is absent.

## Plugin architecture
The framework automatically loads `.ps1` and `.psm1` files below `Plugins`.
This removes the need for a central registration list for plugin code.

Component implementations should use the standardized named-parameter contract:

`Invoke-RaynetX -Component $Component -LogRoot $LogRoot -Action $Action`

## Component discovery
Existing built-in components remain in `Components`. New plugin components can
be added without editing the central dispatcher, provided they follow the
framework conventions.

## Still unchanged
`Opt_Action`, `Opt_Critical`, logging, reboot handling, and the DSL remain part
of the package/component model.
