# Framework fix

This version removes positional calls from the component dispatcher and the
known helper calls that could cause PowerShell parameter binding to bind a
hashtable to `-Action`.

All dispatcher component invocations use named parameters:
`-Component`, `-LogRoot`, `-Action`.

A `Test-RaynetFramework` helper is included for development-time consistency checks.
