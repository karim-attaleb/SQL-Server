# SQL Server Instance Upgrade Tool - API Reference

Complete parameter reference for the Export-SqlServerInstance.ps1 script.

## Parameters

### Required Parameters

#### `-SourceInstance` (String)
- **Description**: Source SQL Server instance name or connection string
- **Required**: Yes
- **Examples**: 
  - `"PROD-SQL01"`
  - `"PROD-SQL01\INSTANCE1"`
  - `"192.168.1.100,1433"`

#### `-DestinationInstance` (String)
- **Description**: Destination SQL Server instance name or connection string
- **Required**: Yes
- **Examples**: 
  - `"SQL2022-01"`
  - `"SQL2022-01\INSTANCE1"`
  - `"192.168.1.200,1433"`

#### `-ExportPath` (String)
- **Description**: Path where backup files will be stored
- **Required**: Yes
- **Examples**: 
  - `"D:\SQLBackups"`
  - `"\\BackupServer\SQLMigration"`
  - `"C:\Migration\$(Get-Date -Format 'yyyy-MM-dd')"`

### Authentication Parameters

#### `-SourceCredential` (PSCredential)
- **Description**: Credentials for connecting to source SQL Server
- **Required**: No (uses Windows Authentication if not specified)
- **Usage**: `$cred = Get-Credential; -SourceCredential $cred`

#### `-DestinationCredential` (PSCredential)
- **Description**: Credentials for connecting to destination SQL Server
- **Required**: No (uses Windows Authentication if not specified)
- **Usage**: `$cred = Get-Credential; -DestinationCredential $cred`

### Database Selection Parameters

#### `-DatabaseNames` (String[])
- **Description**: Array of specific database names to export
- **Required**: No (exports all user databases if not specified)
- **Examples**: 
  - `@("MyApp_DB")`
  - `@("MyApp_DB", "Reports_DB", "Analytics_DB")`

#### `-ExcludeDatabases` (String[])
- **Description**: Array of database names to exclude from export
- **Required**: No
- **Examples**: 
  - `@("TempDB_Copy")`
  - `@("Archive_2020", "Archive_2021", "TestDB")`

#### `-ExcludeSystemDatabases` (Switch)
- **Description**: Exclude system databases from export
- **Required**: No
- **Default**: `$true`
- **System Databases**: master, model, msdb, tempdb, distribution, reportserver, reportservertempdb
- **Usage**: 
  - `-ExcludeSystemDatabases` (default, excludes system DBs)
  - `-ExcludeSystemDatabases:$false` (includes system DBs)

#### `-IncludeAllUserDatabases` (Switch)
- **Description**: Explicitly include all user databases (overrides DatabaseNames)
- **Required**: No
- **Default**: `$false`
- **Usage**: `-IncludeAllUserDatabases`
- **Note**: When specified, ignores `-DatabaseNames` parameter but still respects `-ExcludeDatabases`

### Component Export Parameters

#### `-IncludeLogins` (Switch)
- **Description**: Export SQL Server logins and their permissions
- **Required**: No
- **Default**: `$false`
- **Usage**: `-IncludeLogins`

#### `-IncludeJobs` (Switch)
- **Description**: Export SQL Server Agent jobs
- **Required**: No
- **Default**: `$false`
- **Usage**: `-IncludeJobs`

#### `-IncludeLinkedServers` (Switch)
- **Description**: Export linked server configurations
- **Required**: No
- **Default**: `$false`
- **Usage**: `-IncludeLinkedServers`

#### `-IncludeServerSettings` (Switch)
- **Description**: Export server-level configurations
- **Required**: No
- **Default**: `$false`
- **Usage**: `-IncludeServerSettings`

### Operation Mode Parameters

#### `-BackupOnly` (Switch)
- **Description**: Only create backups, do not restore to destination
- **Required**: No
- **Default**: `$false`
- **Usage**: `-BackupOnly`
- **Note**: When specified, `-DestinationInstance` can be set to "dummy"

#### `-RestoreOnly` (Switch)
- **Description**: Only restore from existing backups, do not create new backups
- **Required**: No
- **Default**: `$false`
- **Usage**: `-RestoreOnly`
- **Note**: When specified, `-SourceInstance` can be set to "dummy"

#### `-OverwriteExisting` (Switch)
- **Description**: Overwrite existing databases on destination server
- **Required**: No
- **Default**: `$false`
- **Usage**: `-OverwriteExisting`
- **Warning**: Use with caution as this will replace existing databases

### Compatibility and Warning Parameters

#### `-IgnoreCollationWarnings` (Switch)
- **Description**: Suppress warnings about collation differences between source and destination
- **Required**: No
- **Default**: `$false`
- **Usage**: `-IgnoreCollationWarnings`
- **Note**: Collation differences can cause issues with string comparisons and temporary tables

### Logging Parameters

#### `-LogPath` (String)
- **Description**: Path for detailed transcript logging
- **Required**: No
- **Examples**: 
  - `"C:\Logs\Migration.log"`
  - `"C:\Logs\Migration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"`

## Parameter Combinations

### Common Scenarios

#### 1. Basic Migration (Default Behavior)
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration"
```
- Exports all user databases
- Excludes system databases
- Uses Windows Authentication
- No additional components

#### 2. Complete Migration with All Components
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -IncludeAllUserDatabases `
    -IncludeLogins `
    -IncludeJobs `
    -IncludeLinkedServers `
    -OverwriteExisting `
    -LogPath "D:\Migration\Logs\Complete.log"
```

#### 3. Selective Migration
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -DatabaseNames @("MyApp_DB", "Reports_DB") `
    -ExportPath "D:\Migration" `
    -IncludeLogins
```

#### 4. Backup Only for Staging
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "dummy" `
    -ExportPath "\\BackupServer\Staging" `
    -BackupOnly `
    -ExcludeDatabases @("TempDB", "TestDB")
```

#### 5. Restore Only from Existing Backups
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "dummy" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "\\BackupServer\Staging" `
    -RestoreOnly `
    -OverwriteExisting
```

#### 6. Include System Databases
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "LEGACY-SQL" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -ExcludeSystemDatabases:$false `
    -IgnoreCollationWarnings
```

## Parameter Validation Rules

### Mutually Exclusive Parameters
- `-BackupOnly` and `-RestoreOnly` cannot be used together
- `-DatabaseNames` is ignored when `-IncludeAllUserDatabases` is specified

### Required Combinations
- When using `-BackupOnly`, `-DestinationInstance` is not used (can be set to "dummy")
- When using `-RestoreOnly`, `-SourceInstance` is not used (can be set to "dummy")

### Validation Logic
1. **Connection Testing**: Both source and destination connections are tested before operations
2. **Path Validation**: Export path must be accessible and have sufficient space
3. **Permission Checking**: SQL Server permissions are validated for backup/restore operations
4. **Collation Checking**: Automatic comparison of source and destination collations with warnings

## Return Values and Exit Codes

- **0**: Success - all operations completed successfully
- **1**: Error - critical failure that prevented execution
- **2**: Warning - some operations failed but others succeeded

## Error Handling

The script includes comprehensive error handling:
- Individual database failures don't stop the entire process
- Detailed error messages with recommendations
- Automatic retry logic for transient failures
- Comprehensive logging of all operations and errors

## Performance Considerations

- **Backup Compression**: Enabled by default to reduce file sizes and transfer times
- **Parallel Operations**: Multiple databases can be processed simultaneously
- **Network Optimization**: Local storage recommended for backup files when possible
- **Memory Usage**: Large databases may require additional memory allocation

## Security Considerations

- **Credential Handling**: Use Windows Authentication when possible
- **File Permissions**: Secure backup file locations with appropriate permissions
- **Network Security**: Ensure secure connections between SQL Server instances
- **Audit Logging**: Enable detailed logging for compliance requirements
