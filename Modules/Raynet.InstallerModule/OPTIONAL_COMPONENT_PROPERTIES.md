# Optional component properties

All package component definitions use a central normalization layer. Omitted common options receive defaults.

| Property | Default | Purpose |
|---|---:|---|
| Enabled | `$true` | Skip component when false |
| `Opt_Critical` | `$true` | Failure stops the package when true; when false, log and continue |
| TimeoutSeconds | `0` | No timeout unless component implements one |
| SuccessExitCodes | `@(0,3010)` | Successful process exit codes |
| RebootExitCodes | `@(3010,1641)` | Exit codes requiring reboot |
| Force | `$false` | Force where supported |
| Recurse | `$false` | Recursive operation where supported |
| IgnoreMissing | `$false` | Missing target is non-fatal where supported |
| Verify | `$true` | Verify operation where supported |

Legacy `Opt_*` names are accepted and normalized to their shorter names, so existing packages remain compatible.

Component-specific options remain optional unless required by the selected operation.

`Raynet_AttachSqlDatabase -SqlPassword` and
`Raynet_ConfigureService -Opt_Configure_Password` require a `SecureString`.
Retrieve the password from an approved secret store and pass it without converting
it to plaintext. The SQL handler passes it to `sqlcmd` through the
`SQLCMDPASSWORD` environment variable rather than a command-line argument.
