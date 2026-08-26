# Raynet Installer Framework 0.2 - First Shot

Key changes:
- Restored extensive package comment-based help/header.
- Moved LogRoot and DetectionRoot into Raynet.Installer.ini.
- Main log is stored in <LogRoot>\<Package>\<Package>_<Action>.log.
- Component logs are stored in <LogRoot>\<Package>\Components\<Component>\.
- Human-readable result messages are written to main and component logs.
- Idempotent service stop/configure operations treat a missing service as an already-satisfied successful state.
- Opt_Critical is the sole package-flow failure control; ContinueOnError was removed from the public DSL.
- Dispatcher uses convention-based Type -> Invoke-Raynet<Type> resolution.
- Plugins are discovered recursively below Plugins. No central dispatcher registration is needed.
- Component definition functions no longer emit their internal hashtables to the console.
