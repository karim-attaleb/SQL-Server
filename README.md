# SQL Server Instance Upgrade Tool

A comprehensive PowerShell solution for migrating SQL Server instances to SQL Server 2022 using dbatools. This tool provides robust functionality for selective database migration with advanced features like collation checking and flexible database selection.

## 🚀 Features

- **Selective Database Export**: Choose specific databases or export all user databases
- **System Database Control**: Configurable exclusion of system databases (enabled by default)
- **Collation Compatibility Checking**: Warns about collation differences between source and destination
- **Encryption Support**: Both at-rest (backup files) and in-flight (SQL connections) encryption
- **Backup Encryption**: AES128, AES192, AES256, and TRIPLEDES algorithms with certificate-based encryption
- **Connection Encryption**: TLS/SSL encryption for SQL Server connections with certificate validation
- **Flexible Operation Modes**: Backup-only, restore-only, or full migration
- **Additional Components**: Optional export of logins, SQL Agent jobs, linked servers
- **Robust Error Handling**: Comprehensive logging and error reporting
- **Progress Tracking**: Real-time status updates with colored output
- **Flexible Authentication**: Supports both Windows and SQL Server authentication

## 📁 Repository Structure

```
sql-server-instance-upgrade/
├── scripts/
│   ├── Export-SqlServerInstance.ps1    # Main migration script
│   ├── Install-Prerequisites.ps1       # Environment setup
│   ├── Test-Prerequisites.ps1          # Environment validation
│   └── Validate-Script.ps1            # Script validation
├── docs/
│   ├── DEPLOYMENT_GUIDE.md            # Deployment instructions
│   └── API_REFERENCE.md               # Parameter reference
├── examples/
│   └── Usage-Examples.ps1             # Real-world scenarios
└── tests/
    └── (future test files)
```

## 🎯 Quick Start

1. **Clone the repository**:
   ```bash
   git clone https://github.com/karim-attaleb/sql-server-instance-upgrade.git
   cd sql-server-instance-upgrade
   ```

2. **Install prerequisites**:
   ```powershell
   .\scripts\Install-Prerequisites.ps1
   ```

3. **Test your environment**:
   ```powershell
   .\scripts\Test-Prerequisites.ps1 -SourceInstance "YourSource" -DestinationInstance "YourDest"
   ```

4. **Run migration**:
   ```powershell
   .\scripts\Export-SqlServerInstance.ps1 `
       -SourceInstance "PROD-SQL01" `
       -DestinationInstance "SQL2022-SERVER" `
       -ExportPath "D:\SQLMigration"
   ```

## 🆕 Key Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `SourceInstance` | String | Required | Source SQL Server instance |
| `DestinationInstance` | String | Required | Destination SQL Server instance |
| `ExportPath` | String | Required | Path for backup files |
| `ExcludeSystemDatabases` | Switch | `$true` | Exclude system databases |
| `IncludeAllUserDatabases` | Switch | `$false` | Include all user databases |
| `IgnoreCollationWarnings` | Switch | `$false` | Suppress collation warnings |
| `EncryptConnections` | Switch | `$false` | Enable TLS/SSL encryption for connections |
| `TrustServerCertificate` | Switch | `$false` | Trust server certificates (use with caution) |
| `BackupEncryptionAlgorithm` | String | None | Encryption algorithm for backup files |
| `BackupEncryptionCertificate` | String | None | Certificate name for backup encryption |
| `IncludeLogins` | Switch | `$false` | Export SQL Server logins |
| `IncludeJobs` | Switch | `$false` | Export SQL Agent jobs |
| `OverwriteExisting` | Switch | `$false` | Overwrite existing databases |

## 📖 Documentation

- [Deployment Guide](docs/DEPLOYMENT_GUIDE.md) - Step-by-step setup and deployment
- [API Reference](docs/API_REFERENCE.md) - Complete parameter documentation
- [Usage Examples](examples/Usage-Examples.ps1) - Real-world migration scenarios

## 🛡️ Safety Features

- **Connection testing** before operations begin
- **Collation compatibility checking** with detailed warnings
- **Individual database error handling** - one failure doesn't stop the process
- **Backup verification** before attempting restores
- **Overwrite protection** - requires explicit flag
- **Comprehensive logging** with detailed error messages

## 🔧 System Requirements

- **Windows Server 2016+** or **Windows 10+**
- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **dbatools PowerShell module**
- **Network access** to both source and destination SQL Servers
- **Appropriate SQL Server permissions** (sysadmin recommended)

## 📝 Usage Examples

### Basic Migration
```powershell
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration"
```

### Selective Migration with Components
```powershell
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -DatabaseNames @("MyApp_DB", "Reports_DB") `
    -ExportPath "D:\Migration" `
    -IncludeLogins `
    -IncludeJobs `
    -OverwriteExisting
```

### Include All User Databases
```powershell
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -IncludeAllUserDatabases `
    -IncludeLogins
```

### Encrypted Migration with Backup Encryption
```powershell
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -EncryptConnections `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "BackupCert" `
    -IncludeLogins
```

### Maximum Security Migration
```powershell
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SecureMigration" `
    -EncryptConnections `
    -TrustServerCertificate `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "BackupCert" `
    -IncludeAllUserDatabases `
    -IncludeLogins `
    -IncludeJobs
```

## 🤝 Contributing

This tool was created for @karim-attaleb. Feel free to submit issues or enhancement requests.

## 📄 License

This tool is provided as-is for educational and operational purposes. Please ensure compliance with your organization's policies and Microsoft SQL Server licensing requirements.

## 🔗 Links

- **dbatools Documentation**: [dbatools.io](https://dbatools.io)
- **SQL Server 2022 Documentation**: [Microsoft Docs](https://docs.microsoft.com/sql/sql-server/)

---

**Created by**: @karim-attaleb  
**Repository**: https://github.com/karim-attaleb/sql-server-instance-upgrade
