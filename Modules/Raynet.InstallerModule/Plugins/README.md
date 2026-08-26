# Raynet 0.2 plugins

A plugin can add a new component without editing the core dispatcher.

For Type `FirewallRule`, provide an implementation named:

    Invoke-RaynetFirewallRule

with the standard signature:

    -Component <hashtable> -LogRoot <string> -Action Install|Uninstall

Also provide a public DSL function such as `Raynet_FirewallRule` that calls
`Add-RaynetComponent` with `Type='FirewallRule'`.

Drop `.ps1` files anywhere below `Plugins`, or a `.psm1` plugin module. The
framework loads them automatically. Use named parameters for all internal calls.
