# SQL Server Export Tool - Deployment Guide

## Quick Start

1. **Download all files** to a Windows machine with PowerShell
2. **Install prerequisites**: Run `.\Install-Prerequisites.ps1`
3. **Test environment**: Run `.\Test-Prerequisites.ps1 -SourceInstance "YourSource" -DestinationInstance "YourDest"`
4. **Run migration**: Use `.\Export-SqlServerInstance.ps1` with your parameters

## File Overview

| File | Purpose |
|------|---------|
| `Export-SqlServerInstance.ps1` | Main export script |
| `Install-Prerequisites.ps1` | Sets up dbatools and environment |
| `Test-Prerequisites.ps1` | Validates environment before migration |
| `Examples.ps1` | Usage examples and scenarios |
| `Validate-Script.ps1` | Validates script syntax and structure |
| `README.md` | Comprehensive documentation |
| `DEPLOYMENT_GUIDE.md` | This deployment guide |

## System Requirements

- **Windows Server 2016+** or **Windows 10+**
- **PowerShell 5.1+** (PowerShell 7+ recommended)
- **Network access** to both source and destination SQL Servers
- **Sufficient disk space** for backup files
- **Appropriate SQL Server permissions** (sysadmin recommended)

## Installation Steps

### Step 1: Download and Extract
```powershell
# Download all files to a folder, e.g., C:\SQLExportTool\
# Ensure all 7 files are present
```

### Step 2: Set Execution Policy
```powershell
# Run PowerShell as Administrator
Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope LocalMachine
```

### Step 3: Install Prerequisites
```powershell
# Navigate to the tool directory
cd C:\SQLExportTool\

# Install required modules and configure environment
.\Install-Prerequisites.ps1
```

### Step 4: Validate Installation
```powershell
# Test script syntax and structure
.\Validate-Script.ps1

# Test environment and connectivity
.\Test-Prerequisites.ps1 -SourceInstance "YourSourceServer" -DestinationInstance "YourDestServer"
```

## Common Usage Scenarios

### Scenario 1: Complete Migration
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SQLMigration" `
    -IncludeLogins `
    -IncludeJobs `
    -LogPath "D:\SQLMigration\Logs\Migration.log"
```

### Scenario 1a: Migration Including System Databases
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "LEGACY-SQL" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SQLMigration" `
    -ExcludeSystemDatabases:$false `
    -IgnoreCollationWarnings `
    -IncludeLogins `
    -LogPath "D:\SQLMigration\Logs\SystemDB_Migration.log"
```

### Scenario 1b: Explicitly Include All User Databases
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SQLMigration" `
    -IncludeAllUserDatabases `
    -IncludeLogins `
    -IncludeJobs `
    -LogPath "D:\SQLMigration\Logs\AllUserDB_Migration.log"
```

### Scenario 2: Selective Database Migration
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -DatabaseNames @("MyApp_DB", "Reporting_DB") `
    -ExportPath "D:\SQLMigration" `
    -OverwriteExisting
```

### Scenario 3: Backup Only (for staging)
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "dummy" `
    -ExportPath "\\BackupServer\SQLBackups" `
    -BackupOnly
```

### Scenario 4: Restore Only (from existing backups)
```powershell
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "dummy" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "\\BackupServer\SQLBackups" `
    -RestoreOnly `
    -OverwriteExisting
```

### Scenario 5: Encrypted Migration with Maximum Security
```powershell
# Create backup encryption certificate first (run on source server)
# CREATE CERTIFICATE BackupCert
# WITH SUBJECT = 'Database Backup Encryption Certificate';

# Encrypted migration with both connection and backup encryption
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SecureMigration" `
    -EncryptConnections `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "BackupCert" `
    -IncludeLogins `
    -IncludeJobs `
    -LogPath "D:\SecureMigration\Logs\Encrypted_Migration.log"
```

### Scenario 6: Compliance Migration with Encrypted Backups
```powershell
# Backup-only with encryption for compliance requirements
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "COMPLIANCE-SQL" `
    -DestinationInstance "dummy" `
    -ExportPath "\\SecureStorage\ComplianceBackups" `
    -BackupOnly `
    -EncryptConnections `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "ComplianceCert" `
    -ExcludeDatabases @("TempDB", "TestDB") `
    -LogPath "\\SecureStorage\ComplianceBackups\Logs\Compliance.log"
```

## Security Considerations

### Authentication
- Use Windows Authentication when possible for better security
- Store SQL Server credentials securely if SQL Authentication is required
- Consider using service accounts with minimal required permissions

### Network Security
- Ensure network connectivity between source and destination servers
- Consider firewall rules for SQL Server ports (default 1433)
- Use VPN or private networks for sensitive data migrations
- Enable connection encryption for sensitive data transfers

### Backup File Security
- Secure backup file locations with appropriate NTFS permissions
- Use backup encryption for sensitive data protection
- Implement backup file retention policies
- Monitor backup file access and modifications

### Event Log Security
- Event Log source creation requires administrative privileges
- Event Log entries are visible to users with Event Log read permissions
- Consider using custom event sources for better log organization
- Monitor Event Log entries for security and compliance requirements

## Encryption Setup and Best Practices

### Certificate Management for Backup Encryption

#### Creating Backup Encryption Certificates
```sql
-- Run on source SQL Server instance
USE master;
GO

-- Create a master key if it doesn't exist
CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'StrongPassword123!';
GO

-- Create backup encryption certificate
CREATE CERTIFICATE BackupCert
WITH SUBJECT = 'Database Backup Encryption Certificate',
EXPIRY_DATE = '2025-12-31';
GO

-- Backup the certificate and private key for disaster recovery
BACKUP CERTIFICATE BackupCert
TO FILE = 'C:\Certificates\BackupCert.cer'
WITH PRIVATE KEY (
    FILE = 'C:\Certificates\BackupCert.pvk',
    ENCRYPTION BY PASSWORD = 'CertificatePassword123!'
);
GO
```

#### Certificate Security Best Practices
- **Secure Storage**: Store certificate files in secure locations with restricted access
- **Password Protection**: Use strong passwords for certificate private keys
- **Backup Strategy**: Include certificates in disaster recovery procedures
- **Expiration Monitoring**: Monitor certificate expiration dates and renew before expiry
- **Access Control**: Limit certificate access to authorized personnel only

### Connection Encryption Best Practices

#### Production Environment Setup
- **SSL Certificates**: Use properly signed SSL certificates in production
- **Certificate Validation**: Avoid TrustServerCertificate in production environments
- **Network Isolation**: Use private networks for database migrations
- **Monitoring**: Monitor encrypted connections for performance impact

#### Development and Testing
- **Self-Signed Certificates**: Acceptable for development environments
- **TrustServerCertificate**: Can be used with caution in test environments
- **Performance Testing**: Test encryption impact on migration performance

### Compliance Considerations
- **Data Classification**: Identify sensitive data requiring encryption
- **Regulatory Requirements**: Ensure encryption meets compliance standards
- **Audit Trails**: Maintain detailed logs of encrypted operations
- **Key Management**: Implement proper encryption key lifecycle management

## Event Log Configuration and Monitoring

### Event Log Setup
```powershell
# Enable Event Log with default source
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -EnableEventLogging

# Enable Event Log with custom source (requires admin privileges)
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -EnableEventLogging `
    -EventLogSource "MyMigrationTool"
```

### Event Log Categories and IDs
- **Information Events (ID 1000)**: General information messages
- **Success Events (ID 1001)**: Successful operations
- **Warning Events (ID 2001)**: Non-critical warnings
- **Error Events (ID 3001)**: Error conditions

### Event Log Monitoring
```powershell
# View migration events in PowerShell
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='SQLServerMigrationTool'}

# Filter by event level
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='SQLServerMigrationTool'; Level=2} # Errors only
```

### Event Log Best Practices
- **Source Registration**: Run initial setup with administrative privileges to register custom event sources
- **Log Retention**: Configure appropriate Event Log retention policies
- **Monitoring**: Set up monitoring alerts for error events (ID 3001)
- **Cleanup**: Regularly review and archive old Event Log entries

### Authentication Methods

**Windows Authentication (Recommended):**
```powershell
# Run PowerShell with appropriate Windows credentials
# Script will use current Windows identity
.\Export-SqlServerInstance.ps1 -SourceInstance "Server1" -DestinationInstance "Server2" -ExportPath "C:\Backups"
```

**SQL Server Authentication:**
```powershell
# Prompt for credentials securely
$sourceCred = Get-Credential -Message "Source SQL Server Login"
$destCred = Get-Credential -Message "Destination SQL Server Login"

.\Export-SqlServerInstance.ps1 `
    -SourceInstance "Server1" `
    -DestinationInstance "Server2" `
    -SourceCredential $sourceCred `
    -DestinationCredential $destCred `
    -ExportPath "C:\Backups"
```

### Required Permissions

**Source Server:**
- `db_backupoperator` role (minimum)
- `sysadmin` role (recommended for complete migration)
- Read access to all databases to be migrated

**Destination Server:**
- `db_creator` role (minimum)
- `sysadmin` role (recommended for complete migration)
- Write access to default database and log directories

**File System:**
- Read/write access to backup directory
- Sufficient disk space (estimate 30-50% of source database sizes)

## Troubleshooting

### Common Issues

**1. "dbatools module not found"**
```powershell
# Solution: Install dbatools
Install-Module dbatools -Force -AllowClobber
Import-Module dbatools
```

**2. "Access denied" errors**
```powershell
# Solution: Check SQL Server permissions
# Ensure login has appropriate roles on both servers
# Consider using sysadmin role for migration operations
```

**3. "Network path not found"**
```powershell
# Solution: Check network connectivity
Test-NetConnection -ComputerName "YourSQLServer" -Port 1433
# Verify SQL Server Browser service is running
# Check firewall settings
```

**4. "Insufficient disk space"**
```powershell
# Solution: Use different backup location or clean up space
# Consider using network storage
# Use compressed backups (enabled by default)
```

**5. "Database already exists"**
```powershell
# Solution: Use -OverwriteExisting parameter
# Or manually drop/rename existing databases
```

### Performance Optimization

**For Large Databases:**
- Use local storage for backup files when possible
- Schedule migrations during low-activity periods
- Consider breaking large migrations into smaller batches
- Monitor disk I/O and network bandwidth

**For Multiple Databases:**
- Use selective migration for critical databases first
- Test with smaller databases before migrating large ones
- Consider parallel operations for independent databases

## Monitoring and Logging

### Enable Detailed Logging
```powershell
$logPath = "C:\SQLMigration\Logs\Migration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

.\Export-SqlServerInstance.ps1 `
    -SourceInstance "Source" `
    -DestinationInstance "Dest" `
    -ExportPath "C:\Backups" `
    -LogPath $logPath
```

### Monitor Progress
- Watch console output for real-time status
- Check log files for detailed operation history
- Monitor disk space during backup operations
- Verify database restoration success

## Post-Migration Tasks

### Verification Steps
1. **Database Integrity**: Run `DBCC CHECKDB` on restored databases
2. **User Access**: Verify logins and permissions work correctly
3. **Application Testing**: Test application connectivity and functionality
4. **Performance**: Compare query performance between old and new systems

### Cleanup Tasks
1. **Remove Backup Files**: Clean up temporary backup files after successful migration
2. **Update Connection Strings**: Update applications to point to new SQL Server
3. **Update Documentation**: Document the new server configuration
4. **Monitor Performance**: Establish baseline performance metrics

## Support and Resources

- **dbatools Documentation**: [dbatools.io](https://dbatools.io)
- **SQL Server 2022 Documentation**: [Microsoft Docs](https://docs.microsoft.com/sql/sql-server/)
- **PowerShell Documentation**: [Microsoft PowerShell Docs](https://docs.microsoft.com/powershell/)

## Version History

- **v1.0**: Initial release with comprehensive migration functionality
- Supports SQL Server 2008+ to SQL Server 2022 migrations
- Includes selective database export and additional component migration
- Comprehensive error handling and logging capabilities
