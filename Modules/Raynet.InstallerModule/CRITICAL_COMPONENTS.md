# Critical components

Every `Raynet_*` component supports:

```powershell
-Opt_Critical $true|$false
```

Default: `$true`.

- `$true`: a failed component stops package execution and the package returns failure.
- `$false`: the failure is logged as a warning, recorded in the package result, and execution continues.

translated to the equivalent critical setting.

`Opt_Action` remains independent:

- `Default`: follow package action
- `Install`: execute only for install
- `Uninstall`: execute only for uninstall

Thus a component can be non-critical and independently override the package action.
