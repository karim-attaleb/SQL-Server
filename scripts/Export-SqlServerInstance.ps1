<#
.SYNOPSIS
    Exports a SQL Server instance to SQL Server 2022 using modular architecture

.DESCRIPTION
    This script provides a wrapper for the Export-SqlServerInstance function from the SqlServerMigration module.
    It maintains backward compatibility while using the new modular architecture.

.PARAMETER SourceInstance
    Source SQL Server instance name or connection string
    
.PARAMETER DestinationInstance
    Destination SQL Server instance name or connection string
    
.PARAMETER SourceCredential
    Credentials for source server (optional - uses Windows Authentication if not provided)
    
.PARAMETER DestinationCredential
    Credentials for destination server (optional - uses Windows Authentication if not provided)
    
.PARAMETER DatabaseNames
    Array of specific database names to export (optional)
    
.PARAMETER ExcludeDatabases
    Array of database names to exclude from export
    
.PARAMETER ExportPath
    Path where backup files will be stored
    
.PARAMETER IncludeLogins
    Include SQL Server logins in the export
    
.PARAMETER IncludeJobs
    Include SQL Server Agent jobs in the export
    
.PARAMETER IncludeLinkedServers
    Include linked servers in the export
    
.PARAMETER IncludeServerSettings
    Include server-level settings in the export
    
.PARAMETER BackupOnly
    Only perform backup operations (no restore)
    
.PARAMETER RestoreOnly
    Only perform restore operations (no backup)
    
.PARAMETER OverwriteExisting
    Overwrite existing databases on destination server
    
.PARAMETER ExcludeSystemDatabases
    Exclude system databases from export (enabled by default)
    
.PARAMETER IncludeAllUserDatabases
    Include all user databases (overrides DatabaseNames parameter)
    
.PARAMETER IgnoreCollationWarnings
    Suppress warnings about collation differences between source and destination
    
.PARAMETER LogPath
    Path for detailed logging (optional)

.PARAMETER EncryptConnections
    Enable TLS/SSL encryption for SQL Server connections (in-flight encryption)
    
.PARAMETER TrustServerCertificate
    Trust server certificates when using encrypted connections (use with caution)
    
.PARAMETER BackupEncryptionAlgorithm
    Encryption algorithm for backup files: AES128, AES192, AES256, or TRIPLEDES
    
.PARAMETER BackupEncryptionCertificate
    Certificate name in master database for backup encryption (at-rest encryption)

.PARAMETER EnableEventLogging
    Enable logging to Windows Event Log in addition to console output

.PARAMETER EventLogSource
    Custom event log source name (default: SQLServerMigrationTool)
     
.EXAMPLE
    .\Export-SqlServerInstance.ps1 -SourceInstance "Server1\Instance1" -DestinationInstance "Server2\Instance2" -ExportPath "C:\Backups"
    
.EXAMPLE
    .\Export-SqlServerInstance.ps1 -SourceInstance "Server1" -DestinationInstance "Server2" -DatabaseNames @("DB1", "DB2") -IncludeLogins -IncludeJobs

.EXAMPLE
    .\Export-SqlServerInstance.ps1 -SourceInstance "Server1" -DestinationInstance "Server2" -ExportPath "C:\Backups" -EncryptConnections -BackupEncryptionAlgorithm "AES256" -BackupEncryptionCertificate "BackupCert"

.EXAMPLE
    .\Export-SqlServerInstance.ps1 -SourceInstance "Server1" -DestinationInstance "Server2" -ExportPath "C:\Backups" -EnableEventLogging -EventLogSource "MyMigrationTool"
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $true)]
    [string]$SourceInstance,
    
    [Parameter(Mandatory = $true)]
    [string]$DestinationInstance,
    
    [PSCredential]$SourceCredential,
    
    [PSCredential]$DestinationCredential,
    
    [string[]]$DatabaseNames,
    
    [string[]]$ExcludeDatabases = @(),
    
    [Parameter(Mandatory = $true)]
    [string]$ExportPath,
    
    [switch]$IncludeLogins,
    
    [switch]$IncludeJobs,
    
    [switch]$IncludeLinkedServers,
    
    [switch]$IncludeServerSettings,
    
    [switch]$BackupOnly,
    
    [switch]$RestoreOnly,
    
    [switch]$OverwriteExisting,
    
    [switch]$ExcludeSystemDatabases = $true,
    
    [switch]$IncludeAllUserDatabases,
    
    [switch]$IgnoreCollationWarnings,
    
    [switch]$EncryptConnections,
    
    [switch]$TrustServerCertificate,
    
    [ValidateSet("AES128", "AES192", "AES256", "TRIPLEDES")]
    [string]$BackupEncryptionAlgorithm,
    
    [string]$BackupEncryptionCertificate,
    
    [string]$LogPath,
    
    [switch]$EnableEventLogging,
    
    [string]$EventLogSource = "SQLServerMigrationTool"
)

# Import SqlServerMigration module
$ModulePath = Join-Path $PSScriptRoot "..\modules\SqlServerMigration\SqlServerMigration.psd1"
try {
    Import-Module $ModulePath -Force
    Write-Host "✓ SqlServerMigration module imported successfully" -ForegroundColor Green
}
catch {
    Write-Host "✗ Failed to import SqlServerMigration module: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host "ℹ Please ensure the module is available at: $ModulePath" -ForegroundColor Cyan
    exit 1
}

# Call the Export-SqlServerInstance function from the module with all parameters
$exportParams = @{
    SourceInstance = $SourceInstance
    DestinationInstance = $DestinationInstance
    ExportPath = $ExportPath
    ExcludeSystemDatabases = $ExcludeSystemDatabases
    IncludeAllUserDatabases = $IncludeAllUserDatabases
    IgnoreCollationWarnings = $IgnoreCollationWarnings
    EncryptConnections = $EncryptConnections
    TrustServerCertificate = $TrustServerCertificate
    BackupOnly = $BackupOnly
    RestoreOnly = $RestoreOnly
    OverwriteExisting = $OverwriteExisting
    IncludeLogins = $IncludeLogins
    IncludeJobs = $IncludeJobs
    IncludeLinkedServers = $IncludeLinkedServers
    IncludeServerSettings = $IncludeServerSettings
    EnableEventLogging = $EnableEventLogging
    EventLogSource = $EventLogSource
}

# Add optional parameters if provided
if ($SourceCredential) { $exportParams.SourceCredential = $SourceCredential }
if ($DestinationCredential) { $exportParams.DestinationCredential = $DestinationCredential }
if ($DatabaseNames) { $exportParams.DatabaseNames = $DatabaseNames }
if ($ExcludeDatabases) { $exportParams.ExcludeDatabases = $ExcludeDatabases }
if ($BackupEncryptionAlgorithm) { $exportParams.BackupEncryptionAlgorithm = $BackupEncryptionAlgorithm }
if ($BackupEncryptionCertificate) { $exportParams.BackupEncryptionCertificate = $BackupEncryptionCertificate }
if ($LogPath) { $exportParams.LogPath = $LogPath }

# Execute the migration using the modular function
Export-SqlServerInstance @exportParams
