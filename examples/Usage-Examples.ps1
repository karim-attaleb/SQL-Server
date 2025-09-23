# SQL Server Export Tool - Usage Examples
# This file contains various usage examples for the Export-SqlServerInstance.ps1 script

# Example 1: Basic migration of all user databases
Write-Host "Example 1: Basic Migration" -ForegroundColor Yellow
$example1 = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "DEV-SQL02" `
    -ExportPath "C:\SQLBackups"
'@
Write-Host $example1 -ForegroundColor Green

# Example 2: Selective database migration with additional components
Write-Host "`nExample 2: Selective Migration with Components" -ForegroundColor Yellow
$example2 = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01\INSTANCE1" `
    -DestinationInstance "DEV-SQL02\INSTANCE2" `
    -DatabaseNames @("MyApp_Production", "MyApp_Reporting", "MyApp_Analytics") `
    -ExportPath "D:\SQLMigration\Backups" `
    -IncludeLogins `
    -IncludeJobs `
    -IncludeLinkedServers `
    -OverwriteExisting `
    -LogPath "C:\Logs\Migration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
'@
Write-Host $example2 -ForegroundColor Green

# Example 3: Backup-only operation for staging
Write-Host "`nExample 3: Backup Only for Staging" -ForegroundColor Yellow
$example3 = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "dummy" `
    -ExportPath "\\BackupServer\SQLMigration\$(Get-Date -Format 'yyyy-MM-dd')" `
    -BackupOnly `
    -ExcludeDatabases @("TempDB_Copy", "TestDB", "ScratchPad") `
    -LogPath "\\BackupServer\Logs\Backup_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
'@
Write-Host $example3 -ForegroundColor Green

# Example 4: Restore-only operation from existing backups
Write-Host "`nExample 4: Restore Only from Existing Backups" -ForegroundColor Yellow
$example4 = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "dummy" `
    -DestinationInstance "TEST-SQL03" `
    -ExportPath "\\BackupServer\SQLMigration\2024-01-15" `
    -RestoreOnly `
    -OverwriteExisting `
    -LogPath "C:\Logs\Restore_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
'@
Write-Host $example4 -ForegroundColor Green

# Example 5: Migration with SQL Server Authentication
Write-Host "`nExample 5: Migration with SQL Authentication" -ForegroundColor Yellow
$example5 = @'
# First, get credentials securely
$sourceCredential = Get-Credential -Message "Enter source SQL Server credentials (sa or admin account)"
$destCredential = Get-Credential -Message "Enter destination SQL Server credentials"

.\Export-SqlServerInstance.ps1 `
    -SourceInstance "192.168.1.100,1433" `
    -DestinationInstance "192.168.1.200,1433" `
    -SourceCredential $sourceCredential `
    -DestinationCredential $destCredential `
    -ExportPath "C:\SQLMigration" `
    -IncludeLogins `
    -DatabaseNames @("CustomerDB", "OrdersDB", "InventoryDB")
'@
Write-Host $example5 -ForegroundColor Green

# Example 6: Large-scale migration with exclusions
Write-Host "`nExample 6: Large Scale Migration with Exclusions" -ForegroundColor Yellow
$example6 = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "ENTERPRISE-SQL01\PROD" `
    -DestinationInstance "CLOUD-SQL01\MIGRATION" `
    -ExportPath "E:\LargeMigration\Backups" `
    -ExcludeDatabases @("Archive_2020", "Archive_2021", "TempProcessing", "ETL_Staging") `
    -IncludeLogins `
    -IncludeJobs `
    -IncludeLinkedServers `
    -LogPath "E:\LargeMigration\Logs\Migration_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
'@
Write-Host $example6 -ForegroundColor Green

# Example 6a: Migration including system databases with collation warnings suppressed
Write-Host "`nExample 6a: Migration Including System Databases" -ForegroundColor Yellow
$example6a = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "LEGACY-SQL2008" `
    -DestinationInstance "SQL2022-UPGRADE" `
    -ExportPath "D:\SystemMigration" `
    -ExcludeSystemDatabases:$false `
    -IgnoreCollationWarnings `
    -IncludeLogins `
    -IncludeJobs `
    -LogPath "D:\SystemMigration\Logs\SystemDB_Migration.log"
'@
Write-Host $example6a -ForegroundColor Green

# Example 6b: Explicitly include all user databases
Write-Host "`nExample 6b: Include All User Databases Explicitly" -ForegroundColor Yellow
$example6b = @'
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\AllUserDBMigration" `
    -IncludeAllUserDatabases `
    -IncludeLogins `
    -IncludeJobs `
    -LogPath "D:\AllUserDBMigration\Logs\AllUserDB_Migration.log"
'@
Write-Host $example6b -ForegroundColor Green

# Example 7: Development environment refresh
Write-Host "`nExample 7: Development Environment Refresh" -ForegroundColor Yellow
$example7 = @'
# Refresh development environment with production data
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "DEV-SQL01" `
    -DatabaseNames @("MyApp_Core", "MyApp_Config", "MyApp_Lookup") `
    -ExportPath "C:\DevRefresh\$(Get-Date -Format 'yyyy-MM-dd')" `
    -OverwriteExisting `
    -LogPath "C:\DevRefresh\Logs\Refresh_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
'@
Write-Host $example7 -ForegroundColor Green

# Example 8: Disaster recovery preparation
Write-Host "`nExample 8: Disaster Recovery Preparation" -ForegroundColor Yellow
$example8 = @'
# Create DR-ready backups with all components
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "PRIMARY-SQL01\PROD" `
    -DestinationInstance "DR-SQL01\STANDBY" `
    -ExportPath "\\DR-Storage\SQLBackups\$(Get-Date -Format 'yyyy-MM-dd')" `
    -IncludeLogins `
    -IncludeJobs `
    -IncludeLinkedServers `
    -IncludeServerSettings `
    -LogPath "\\DR-Storage\Logs\DR_Prep_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"
'@
Write-Host $example8 -ForegroundColor Green

# Example 9: Testing connectivity before migration
Write-Host "`nExample 9: Pre-Migration Testing Script" -ForegroundColor Yellow
$example9 = @'
# Test script to verify connectivity and permissions before migration
param(
    [string]$SourceInstance = "PROD-SQL01",
    [string]$DestinationInstance = "DEV-SQL02"
)

# Test source connection
try {
    $sourceConn = Connect-DbaInstance -SqlInstance $SourceInstance
    Write-Host "✓ Source connection successful: $($sourceConn.VersionString)" -ForegroundColor Green
    
    # Test backup permissions
    $testBackup = "C:\Temp\ConnTest_$(Get-Date -Format 'yyyyMMddHHmmss').bak"
    Backup-DbaDatabase -SqlInstance $SourceInstance -Database "master" -Path $testBackup -Type "Full"
    Remove-Item $testBackup -Force
    Write-Host "✓ Source backup permissions verified" -ForegroundColor Green
}
catch {
    Write-Host "✗ Source connection failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test destination connection
try {
    $destConn = Connect-DbaInstance -SqlInstance $DestinationInstance
    Write-Host "✓ Destination connection successful: $($destConn.VersionString)" -ForegroundColor Green
    
    # Verify SQL Server 2022 or compatible version
    if ($destConn.VersionMajor -ge 16) {
        Write-Host "✓ Destination is SQL Server 2022 or later" -ForegroundColor Green
    }
    else {
        Write-Host "⚠ Destination is not SQL Server 2022 (Version: $($destConn.VersionString))" -ForegroundColor Yellow
    }
}
catch {
    Write-Host "✗ Destination connection failed: $($_.Exception.Message)" -ForegroundColor Red
}
'@
Write-Host $example9 -ForegroundColor Green

# Example 10: Collation-aware migration with detailed checking
Write-Host "`nExample 10: Collation-Aware Migration" -ForegroundColor Yellow
$example10 = @'
# Migration with explicit collation checking and warnings
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "OLD-SQL2012" `
    -DestinationInstance "NEW-SQL2022" `
    -DatabaseNames @("MultiLingual_App", "International_Data") `
    -ExportPath "C:\CollationMigration" `
    -IncludeLogins `
    -LogPath "C:\CollationMigration\Logs\Collation_Check.log"

# Same migration but suppressing collation warnings if differences are acceptable
.\Export-SqlServerInstance.ps1 `
    -SourceInstance "OLD-SQL2012" `
    -DestinationInstance "NEW-SQL2022" `
    -DatabaseNames @("MultiLingual_App", "International_Data") `
    -ExportPath "C:\CollationMigration" `
    -IgnoreCollationWarnings `
    -IncludeLogins `
    -LogPath "C:\CollationMigration\Logs\Collation_Suppressed.log"
'@
Write-Host $example10 -ForegroundColor Green

# Example 11: Scheduled migration with error handling
Write-Host "`nExample 11: Scheduled Migration with Error Handling" -ForegroundColor Yellow
$example11 = @'
# Wrapper script for scheduled migrations with email notifications
param(
    [string]$EmailTo = "dba@company.com",
    [string]$EmailFrom = "sqlmigration@company.com",
    [string]$SMTPServer = "mail.company.com"
)

$migrationStart = Get-Date
$logPath = "C:\SQLMigration\Logs\Scheduled_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

try {
    # Run the migration
    .\Export-SqlServerInstance.ps1 `
        -SourceInstance "PROD-SQL01" `
        -DestinationInstance "BACKUP-SQL01" `
        -ExportPath "\\BackupServer\SQLMigration\Scheduled" `
        -IncludeLogins `
        -IncludeJobs `
        -LogPath $logPath
    
    $migrationEnd = Get-Date
    $duration = $migrationEnd - $migrationStart
    
    # Send success email
    $subject = "SQL Migration Completed Successfully"
    $body = @"
SQL Server migration completed successfully.

Start Time: $migrationStart
End Time: $migrationEnd
Duration: $($duration.ToString())

Log file: $logPath
"@
    
    Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $subject -Body $body -SmtpServer $SMTPServer
}
catch {
    # Send failure email
    $subject = "SQL Migration Failed"
    $body = @"
SQL Server migration failed with error:

Error: $($_.Exception.Message)
Start Time: $migrationStart
Failure Time: $(Get-Date)

Log file: $logPath

Please check the log file for detailed error information.
"@
    
    Send-MailMessage -To $EmailTo -From $EmailFrom -Subject $subject -Body $body -SmtpServer $SMTPServer
    throw
}
'@
Write-Host $example11 -ForegroundColor Green

# =============================================================================
# ENCRYPTION EXAMPLES
# =============================================================================

# Example 15: Migration with Connection Encryption Only
Write-Host "Example 15: Migration with Connection Encryption" -ForegroundColor Green
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\Migration" `
    -EncryptConnections `
    -DatabaseNames @("CriticalDB", "SensitiveDB") `
    -IncludeLogins

# Example 16: Migration with Backup Encryption Only
Write-Host "Example 16: Migration with Backup Encryption" -ForegroundColor Green
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "PROD-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SecureBackups" `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "BackupCert" `
    -IncludeAllUserDatabases

# Example 17: Maximum Security Migration (Both Encryptions)
Write-Host "Example 17: Maximum Security Migration" -ForegroundColor Green
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
    -IncludeJobs `
    -LogPath "D:\SecureMigration\Logs\MaxSecurity.log"

# Example 18: Backup-Only with Encryption for Compliance
Write-Host "Example 18: Encrypted Backup-Only for Compliance" -ForegroundColor Green
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "COMPLIANCE-SQL" `
    -DestinationInstance "dummy" `
    -ExportPath "\\SecureStorage\ComplianceBackups" `
    -BackupOnly `
    -EncryptConnections `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "ComplianceCert" `
    -ExcludeDatabases @("TempDB", "TestDB")

# Example 19: Development Environment with Trusted Certificates
Write-Host "Example 19: Development Migration with Trusted Certificates" -ForegroundColor Green
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "DEV-SQL01" `
    -DestinationInstance "DEV-SQL2022" `
    -ExportPath "D:\DevMigration" `
    -EncryptConnections `
    -TrustServerCertificate `
    -DatabaseNames @("DevApp", "DevReports") `
    -OverwriteExisting

# Example 20: Selective Encryption Based on Data Sensitivity
Write-Host "Example 20: Selective Encryption for Sensitive Databases" -ForegroundColor Green
.\scripts\Export-SqlServerInstance.ps1 `
    -SourceInstance "MIXED-SQL01" `
    -DestinationInstance "SQL2022-01" `
    -ExportPath "D:\SelectiveMigration" `
    -DatabaseNames @("CustomerData", "FinancialRecords", "PersonalInfo") `
    -EncryptConnections `
    -BackupEncryptionAlgorithm "AES256" `
    -BackupEncryptionCertificate "SensitiveDataCert" `
    -IncludeLogins `
    -LogPath "D:\SelectiveMigration\Logs\SensitiveData.log"

Write-Host "`n" -NoNewline
Write-Host "All examples displayed. Copy and modify as needed for your specific requirements." -ForegroundColor Cyan
Write-Host "Remember to test in a non-production environment first!" -ForegroundColor Yellow
