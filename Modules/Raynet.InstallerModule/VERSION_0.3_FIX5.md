# Raynet Installer Framework 0.3 First Shot — Fix 5

Corrected the package-script parameter block introduced in Fix 4.

The final parameter no longer has an illegal trailing comma:

    [switch]$Help,
    [string]$HelpComponent
)

No framework behavior was otherwise changed from Fix 4.
