<#
.SYNOPSIS
    Exports a SQL Server instance to SQL Server 2022 with comprehensive migration capabilities

.DESCRIPTION
    This function provides a complete solution for migrating SQL Server instances to SQL Server 2022.
    It supports selective database export, encryption (at-rest and in-flight), Event Log integration,
    and comprehensive error handling using dbatools.

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
    Export-SqlServerInstance -SourceInstance "Server1\Instance1" -DestinationInstance "Server2\Instance2" -ExportPath "C:\Backups"
    
.EXAMPLE
    Export-SqlServerInstance -SourceInstance "Server1" -DestinationInstance "Server2" -DatabaseNames @("DB1", "DB2") -IncludeLogins -IncludeJobs

.EXAMPLE
    Export-SqlServerInstance -SourceInstance "Server1" -DestinationInstance "Server2" -ExportPath "C:\Backups" -EncryptConnections -BackupEncryptionAlgorithm "AES256" -BackupEncryptionCertificate "BackupCert"

.EXAMPLE
    Export-SqlServerInstance -SourceInstance "Server1" -DestinationInstance "Server2" -ExportPath "C:\Backups" -EnableEventLogging -EventLogSource "MyMigrationTool"
#>

function Export-SqlServerInstance {
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

    # Initialize script-level variables for logging
    $script:LogPath = $LogPath
    $script:EnableEventLogging = $EnableEventLogging
    $script:EventLogSource = $EventLogSource

    # Import required modules
    try {
        Import-Module dbatools -Force
        Write-Status "dbatools module imported successfully" "Success"
    }
    catch {
        Write-Status "Failed to import dbatools module: $($_.Exception.Message)" "Error"
        Write-Status "Please ensure dbatools is installed: Install-Module dbatools" "Info"
        exit 1
    }

    # Start logging if specified
    if ($LogPath) {
        try {
            $logDir = Split-Path $LogPath -Parent
            if (-not (Test-Path $logDir)) {
                New-Item -ItemType Directory -Path $logDir -Force | Out-Null
            }
            Start-Transcript -Path $LogPath -Append
            Write-Status "Logging started: $LogPath" "Info"
        }
        catch {
            Write-Status "Failed to start logging: $($_.Exception.Message)" "Warning"
        }
    }

    # Validate export path
    if (-not (Test-Path $ExportPath)) {
        try {
            New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
            Write-Status "Created export directory: $ExportPath" "Success"
        }
        catch {
            Write-Status "Failed to create export directory: $ExportPath" "Error"
            exit 1
        }
    }

    # Main execution logic
    Write-Status "Starting SQL Server instance export process" "Info"
    Write-Status "Source Instance: $SourceInstance" "Info"
    Write-Status "Destination Instance: $DestinationInstance" "Info"
    Write-Status "Export Path: $ExportPath" "Info"

    # Test connections and get connection objects
    $sourceConnection = $null
    $destinationConnection = $null

    if (-not $RestoreOnly) {
        $sourceConnection = Test-SqlConnection -Instance $SourceInstance -Credential $SourceCredential -Type "source" -EncryptConnection $EncryptConnections -TrustServerCertificate $TrustServerCertificate
        if (-not $sourceConnection) {
            Write-Status "Cannot proceed without source server connection" "Error"
            exit 1
        }
    }

    if (-not $BackupOnly) {
        $destinationConnection = Test-SqlConnection -Instance $DestinationInstance -Credential $DestinationCredential -Type "destination" -EncryptConnection $EncryptConnections -TrustServerCertificate $TrustServerCertificate
        if (-not $destinationConnection) {
            Write-Status "Cannot proceed without destination server connection" "Error"
            exit 1
        }
    }

    # Validate encryption settings
    if ($BackupEncryptionAlgorithm -or $BackupEncryptionCertificate) {
        Write-Status "Validating backup encryption settings" "Info"
        $encryptionValidation = Test-EncryptionSettings -Connection $sourceConnection -BackupEncryptionAlgorithm $BackupEncryptionAlgorithm -BackupEncryptionCertificate $BackupEncryptionCertificate
        
        if (-not $encryptionValidation.BackupEncryptionValid) {
            foreach ($warning in $encryptionValidation.Warnings) {
                Write-Status $warning "Error"
            }
            Write-Status "Cannot proceed with invalid backup encryption settings" "Error"
            exit 1
        }
        
        foreach ($warning in $encryptionValidation.Warnings) {
            Write-Status $warning "Warning"
        }
    }

    # Get databases to export
    if (-not $RestoreOnly) {
        $databasesToExport = Get-UserDatabases -Instance $SourceInstance -Credential $SourceCredential -IncludeDatabases $DatabaseNames -ExcludeDatabases $ExcludeDatabases -ExcludeSystemDatabases $ExcludeSystemDatabases -IncludeAllUserDatabases $IncludeAllUserDatabases
        
        if ($databasesToExport.Count -eq 0) {
            Write-Status "No databases found to export" "Warning"
            exit 0
        }
        
        # Check collation compatibility if both connections are available
        if ($sourceConnection -and $destinationConnection -and -not $BackupOnly) {
            Test-CollationCompatibility -SourceConnection $sourceConnection -DestinationConnection $destinationConnection -Databases $databasesToExport -IgnoreWarnings $IgnoreCollationWarnings
        }
        
        # Backup databases
        Write-Status "Starting database backup process" "Info"
        $backupResults = Backup-UserDatabases -Instance $SourceInstance -Credential $SourceCredential -Databases $databasesToExport -BackupPath $ExportPath -BackupEncryptionAlgorithm $BackupEncryptionAlgorithm -BackupEncryptionCertificate $BackupEncryptionCertificate
        
        # Display backup summary
        $successfulBackups = $backupResults | Where-Object { $_.Success }
        $failedBackups = $backupResults | Where-Object { -not $_.Success }
        
        Write-Status "Backup Summary:" "Info"
        Write-Status "  Successful: $($successfulBackups.Count)" "Success"
        Write-Status "  Failed: $($failedBackups.Count)" "Error"
        
        if ($failedBackups.Count -gt 0) {
            Write-Status "Failed backups:" "Error"
            foreach ($failed in $failedBackups) {
                Write-Status "  - $($failed.DatabaseName): $($failed.Error)" "Error"
            }
        }
    }
    else {
        # Restore only mode - find existing backup files
        Write-Status "Restore-only mode: Looking for existing backup files in $ExportPath" "Info"
        $backupFiles = Get-ChildItem -Path $ExportPath -Filter "*.bak"
        
        if ($backupFiles.Count -eq 0) {
            Write-Status "No backup files found in $ExportPath" "Error"
            exit 1
        }
        
        $backupResults = @()
        foreach ($file in $backupFiles) {
            $dbName = $file.BaseName -replace '_\d{8}_\d{6}$', ''
            $backupResults += @{
                DatabaseName = $dbName
                BackupFile = $file.FullName
                Success = $true
                Size = $file.Length
            }
        }
        
        Write-Status "Found $($backupResults.Count) backup files to restore" "Info"
    }

    # Restore databases (unless backup-only mode)
    if (-not $BackupOnly -and $backupResults.Count -gt 0) {
        Write-Status "Starting database restore process" "Info"
        $restoreResults = Restore-UserDatabases -Instance $DestinationInstance -Credential $DestinationCredential -BackupResults $backupResults -OverwriteExisting $OverwriteExisting
        
        # Display restore summary
        $successfulRestores = $restoreResults | Where-Object { $_.Success }
        $failedRestores = $restoreResults | Where-Object { -not $_.Success }
        
        Write-Status "Restore Summary:" "Info"
        Write-Status "  Successful: $($successfulRestores.Count)" "Success"
        Write-Status "  Failed: $($failedRestores.Count)" "Error"
        
        if ($failedRestores.Count -gt 0) {
            Write-Status "Failed restores:" "Error"
            foreach ($failed in $failedRestores) {
                Write-Status "  - $($failed.DatabaseName): $($failed.Error)" "Error"
            }
        }
    }

    # Export additional components if requested
    if (-not $BackupOnly -and -not $RestoreOnly) {
        if ($IncludeLogins) {
            Export-SqlLogins -SourceInstance $SourceInstance -DestinationInstance $DestinationInstance -SourceCredential $SourceCredential -DestinationCredential $DestinationCredential
        }
        
        if ($IncludeJobs) {
            Export-SqlJobs -SourceInstance $SourceInstance -DestinationInstance $DestinationInstance -SourceCredential $SourceCredential -DestinationCredential $DestinationCredential
        }
        
        if ($IncludeLinkedServers) {
            Export-LinkedServers -SourceInstance $SourceInstance -DestinationInstance $DestinationInstance -SourceCredential $SourceCredential -DestinationCredential $DestinationCredential
        }
    }

    Write-Status "SQL Server export process completed" "Success"

    # Stop logging if enabled
    if ($LogPath) {
        Stop-Transcript
    }
}
