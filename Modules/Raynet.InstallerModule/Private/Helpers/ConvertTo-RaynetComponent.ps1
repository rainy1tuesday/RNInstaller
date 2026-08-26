function ConvertTo-RaynetComponent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [hashtable]$Component
    )

    $defaults = @{
        Enabled = $true
        Opt_Action = 'Default'
        Opt_Critical = $true
        TimeoutSeconds = 0
        SuccessExitCodes = @(0,3010)
        RebootExitCodes = @(3010,1641)
        Force = $false
        Recurse = $false
        IgnoreMissing = $false
        Verify = $true
    }

    foreach ($k in $defaults.Keys) {
        if (-not $Component.ContainsKey($k) -or $null -eq $Component[$k]) { $Component[$k] = $defaults[$k] }
    }

    # Normalize legacy Opt_* names without breaking existing packages.
    $aliases = @{
        Opt_TimeoutSeconds = 'TimeoutSeconds'
        Opt_SuccessExitCodes = 'SuccessCodes'
        Opt_RebootExitCodes = 'RebootCodes'
        Opt_Force = 'Force'
        Opt_Recurse = 'Recurse'
        Opt_Verify = 'Verify'
        Opt_DeleteEmptyDirectories = 'DeleteEmptyDirectories'
        Opt_Configure_StartType = 'StartType'
        Opt_Configure_AccountName = 'AccountName'
        Opt_Configure_Password = 'Password'
        Opt_Description = 'Description'
        Opt_RunAs = 'RunAs'
        Opt_RemoveAfterRun = 'RemoveAfterRun'
    }
    foreach ($old in $aliases.Keys) {
        $new = $aliases[$old]
        if ($Component.ContainsKey($old) -and -not $Component.ContainsKey($new)) { $Component[$new] = $Component[$old] }
    }
$required = @{
        EXE=@('ExePath'); MSI=@('MsiPath','ProductCode'); MSP=@('FileName'); CopyFile=@('SourceFile','TargetFile'); DeleteFiles=@('TargetFolder','FilePattern'); DeleteDirectory=@('Path')
        RegModify=@('RegistryPath','ValueName','RegistryAction'); CreateShortcut=@('Target','ShortcutName')
        Service=@('ServiceName','ServiceAction'); ConfigureService=@('ServiceName'); Process=@('ProcessName')
        ScheduledTask=@('TaskName','Execute'); ModifyIni=@('IniFile','Entries'); AttachSqlDatabase=@('SqlFile'); AddPrivilegeToAccount=@('AccountName','Privilege')
    }
    $errors=@()
    if ([string]::IsNullOrWhiteSpace([string]$Component.Type)) {$errors+='Type is required.'}
    if ([string]::IsNullOrWhiteSpace([string]$Component.Name)) {$errors+='Name is required.'}
    $type=[string]$Component.Type
    if ($required.ContainsKey($type)) { foreach($p in $required[$type]) { if(-not $Component.ContainsKey($p) -or $null -eq $Component[$p] -or [string]::IsNullOrWhiteSpace([string]$Component[$p])) {$errors+="[$p] is required for [$type]."} } }
    if ([int]$Component.TimeoutSeconds -lt 0) {$errors+='TimeoutSeconds cannot be negative.'}
    if ($errors.Count) { throw "Invalid component [$($Component.Name)]: $($errors -join ' ')" }
    return $Component
}
