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
- **Encryption Support**: Comprehensive encryption capabilities for both at-rest and in-flight data protection
- **Connection Encryption**: TLS/SSL encryption for SQL Server connections using `-EncryptConnections` parameter
- **Backup Encryption**: Certificate-based backup file encryption with support for AES128, AES192, AES256, and TRIPLEDES algorithms
- **Certificate Validation**: Automatic validation of backup encryption certificates in master database
- **Encryption Parameter Validation**: Comprehensive validation of encryption settings before operations begin
- **Security Documentation**: Detailed encryption setup guides and best practices
- **Enhanced Examples**: New usage examples demonstrating various encryption scenarios

### Features
- **Connection Security**:
  - `-EncryptConnections` switch for TLS/SSL encrypted SQL Server connections
  - `-TrustServerCertificate` switch for certificate trust management (use with caution)
  - Automatic encryption status reporting during connection testing

- **Backup Security**:
  - `-BackupEncryptionAlgorithm` parameter with validation for AES128, AES192, AES256, TRIPLEDES
  - `-BackupEncryptionCertificate` parameter for certificate-based encryption
  - Certificate existence validation before backup operations
  - Encryption status reporting during backup processes

- **Enhanced Validation**:
  - New `Test-EncryptionSettings` function for comprehensive encryption validation
  - Certificate existence checking in master database
  - Parameter dependency validation (algorithm requires certificate and vice versa)
  - Detailed error messages for encryption configuration issues

### Documentation Updates
- **README.md**: Added encryption features overview and usage examples
- **API_REFERENCE.md**: Complete documentation of new encryption parameters
- **DEPLOYMENT_GUIDE.md**: Encryption setup scenarios and certificate management
- **Usage-Examples.ps1**: Six new examples demonstrating encryption capabilities

### Security Enhancements
- Certificate-based backup encryption for data at rest protection
- TLS/SSL connection encryption for data in transit protection
- Comprehensive encryption validation and error handling
- Security best practices documentation for production deployments

### Backward Compatibility
- All encryption parameters are optional, maintaining full backward compatibility
- Existing scripts continue to work without modification
- No changes to default behavior when encryption parameters are not specified

### Created By
- **Developer**: @karim-attaleb
