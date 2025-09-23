# Changelog

All notable changes to the SQL Server Instance Upgrade Tool will be documented in this file.

## [1.0.0] - 2024-09-23

### Added
- Initial release of SQL Server Instance Upgrade Tool
- Main migration script `Export-SqlServerInstance.ps1` with comprehensive functionality
- Support for selective database export using dbatools
- System database exclusion with configurable `-ExcludeSystemDatabases` parameter (default: true)
- Collation compatibility checking between source and destination servers
- `-IncludeAllUserDatabases` switch for explicit selection of all user databases
- `-IgnoreCollationWarnings` switch to suppress collation compatibility warnings
- Flexible operation modes: backup-only, restore-only, and full migration
- Support for exporting additional components (logins, jobs, linked servers)
- Comprehensive error handling and logging capabilities
- Progress tracking with colored console output
- Authentication support for both Windows and SQL Server authentication

### Features
- **Database Selection**:
  - Selective export with `-DatabaseNames` parameter
  - Exclude specific databases with `-ExcludeDatabases` parameter
  - System database exclusion (configurable)
  - Include all user databases explicitly with `-IncludeAllUserDatabases`

- **Safety and Validation**:
  - Connection testing before operations
  - Collation compatibility checking with detailed warnings
  - Backup verification before restore operations
  - Overwrite protection requiring explicit flag
  - Individual database error handling

- **Additional Components**:
  - SQL Server logins export with `-IncludeLogins`
  - SQL Agent jobs export with `-IncludeJobs`
  - Linked servers export with `-IncludeLinkedServers`
  - Server settings export with `-IncludeServerSettings`

- **Operation Modes**:
  - Full migration (default)
  - Backup-only mode with `-BackupOnly`
  - Restore-only mode with `-RestoreOnly`

### Documentation
- Comprehensive README with quick start guide
- Detailed deployment guide with step-by-step instructions
- Complete API reference with all parameters documented
- Real-world usage examples for common scenarios
- Prerequisites installation and validation scripts

### Scripts Included
- `Export-SqlServerInstance.ps1` - Main migration script
- `Install-Prerequisites.ps1` - Environment setup and dbatools installation
- `Test-Prerequisites.ps1` - Environment validation and connectivity testing
- `Validate-Script.ps1` - PowerShell syntax and structure validation
- `Usage-Examples.ps1` - Collection of real-world migration scenarios

### Requirements
- Windows Server 2016+ or Windows 10+
- PowerShell 5.1+ (PowerShell 7+ recommended)
- dbatools PowerShell module
- Network access to source and destination SQL Server instances
- Appropriate SQL Server permissions (sysadmin recommended)

## [1.1.0] - 2024-09-23

### Added
- **Comprehensive Encryption Support**: Added both at-rest and in-flight encryption capabilities
- **Connection Encryption (In-Flight)**:
  - `EncryptConnections` parameter for TLS/SSL encrypted SQL Server connections
  - `TrustServerCertificate` parameter for certificate trust management
  - Automatic encryption status reporting during connection testing
- **Backup Encryption (At-Rest)**:
  - `BackupEncryptionAlgorithm` parameter supporting AES128, AES192, AES256, TRIPLEDES
  - `BackupEncryptionCertificate` parameter for certificate-based encryption
  - Certificate existence validation before backup operations
  - Encryption status reporting during backup processes
- **Windows Event Log Integration**:
  - `EnableEventLogging` parameter for Windows Event Log support
  - `EventLogSource` parameter for custom event log source names
  - Automatic event categorization (Info=1000, Success=1001, Warning=2001, Error=3001)
  - Graceful fallback handling for event source registration
- **Enhanced Validation**:
  - New `Test-EncryptionSettings` function for comprehensive encryption validation
  - Certificate existence checking in master database
  - Parameter dependency validation (algorithm requires certificate and vice versa)
  - Detailed error messages for encryption configuration issues
- **Documentation Updates**:
  - Updated README.md with encryption and Event Log features
  - Enhanced API_REFERENCE.md with all new parameter documentation
  - Added Event Log setup and monitoring to DEPLOYMENT_GUIDE.md
  - New Event Log usage examples in Usage-Examples.ps1

### Changed
- Enhanced `Write-Status` function to support file logging and Windows Event Log
- Enhanced `Test-SqlConnection` function to support encrypted connections
- Updated `Backup-UserDatabases` function to support backup encryption
- Improved error handling and validation throughout the script

### Security
- Added certificate-based backup encryption for data at rest protection
- Implemented TLS/SSL connection encryption for data in transit protection
- Enhanced security validation and error handling
- Event Log integration for improved audit trails

### Backward Compatibility
- All new parameters are optional, maintaining full backward compatibility
- Existing scripts continue to work without modification
- No changes to default behavior when new parameters are not specified

### Created By
- **Developer**: @karim-attaleb
