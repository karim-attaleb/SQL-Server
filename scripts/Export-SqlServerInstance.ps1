<#
.SYNOPSIS
    Robust SQL Server instance export tool using dbatools
    
.DESCRIPTION
    This script provides a comprehensive solution to export SQL Server instances to SQL Server 2022.
    It allows selective export of user databases and excludes system databases by default.
    
.PARAMETER SourceInstance
    Source SQL Server instance to export from
    
.PARAMETER DestinationInstance
    Destination SQL Server 2022 instance to export to
    
.PARAMETER SourceCredential
    Credentials for source SQL Server instance
    
.PARAMETER DestinationCredential
    Credentials for destination SQL Server instance
    
.PARAMETER DatabaseNames
    Specific database names to export (optional - if not specified, all user databases will be exported)
    
.PARAMETER ExcludeDatabases
    Database names to exclude from export
    
.PARAMETER ExportPath
    Path where backup files will be stored temporarily
    
.PARAMETER IncludeLogins
    Include SQL Server logins in the export
    
.PARAMETER IncludeJobs
    Include SQL Server Agent jobs in the export
    
.PARAMETER IncludeLinkedServers
    Include linked servers in the export
    
.PARAMETER IncludeServerSettings
    Include server-level settings and configurations
    
.PARAMETER BackupOnly
    Only create backups without restoring to destination
    
.PARAMETER RestoreOnly
    Only restore from existing backups (requires ExportPath with backup files)
    
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
    
.EXAMPLE
    .\Export-SqlServerInstance.ps1 -SourceInstance "Server1\Instance1" -DestinationInstance "Server2\Instance2" -ExportPath "C:\Backups"
    
.EXAMPLE
    .\Export-SqlServerInstance.ps1 -SourceInstance "Server1" -DestinationInstance "Server2" -DatabaseNames @("DB1", "DB2") -IncludeLogins -IncludeJobs
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
    
    [string]$LogPath
)

# Import required modules
try {
    Import-Module dbatools -Force
    Write-Host "✓ dbatools module imported successfully" -ForegroundColor Green
}
catch {
    Write-Error "Failed to import dbatools module. Please install it using: Install-Module dbatools -Force"
    exit 1
}

# Initialize logging
if ($LogPath) {
    if (!(Test-Path (Split-Path $LogPath -Parent))) {
        New-Item -ItemType Directory -Path (Split-Path $LogPath -Parent) -Force | Out-Null
    }
    Start-Transcript -Path $LogPath -Append
}

# Create export directory if it doesn't exist
if (!(Test-Path $ExportPath)) {
    try {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
        Write-Host "✓ Created export directory: $ExportPath" -ForegroundColor Green
    }
    catch {
        Write-Error "Failed to create export directory: $ExportPath"
        exit 1
    }
}

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    switch ($Status) {
        "Success" { Write-Host "✓ $Message" -ForegroundColor Green }
        "Warning" { Write-Host "⚠ $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "✗ $Message" -ForegroundColor Red }
        "Info" { Write-Host "ℹ $Message" -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

# Function to test SQL Server connectivity
function Test-SqlConnection {
    param(
        [string]$Instance,
        [PSCredential]$Credential,
        [string]$Type
    )
    
    try {
        Write-Status "Testing connection to $Type server: $Instance" "Info"
        
        $connectionParams = @{
            SqlInstance = $Instance
        }
        
        if ($Credential) {
            $connectionParams.SqlCredential = $Credential
        }
        
        $connection = Connect-DbaInstance @connectionParams
        
        if ($connection) {
            Write-Status "Successfully connected to $Type server: $Instance" "Success"
            Write-Status "Server Version: $($connection.VersionString)" "Info"
            Write-Status "Server Collation: $($connection.Collation)" "Info"
            return $connection
        }
        else {
            Write-Status "Failed to connect to $Type server: $Instance" "Error"
            return $null
        }
    }
    catch {
        Write-Status "Error connecting to $Type server: $Instance - $($_.Exception.Message)" "Error"
        return $null
    }
}

# Function to check collation compatibility
function Test-CollationCompatibility {
    param(
        [object]$SourceConnection,
        [object]$DestinationConnection,
        [object[]]$Databases,
        [bool]$IgnoreWarnings = $false
    )
    
    try {
        Write-Status "Checking collation compatibility..." "Info"
        
        $sourceServerCollation = $SourceConnection.Collation
        $destServerCollation = $DestinationConnection.Collation
        
        Write-Status "Source server collation: $sourceServerCollation" "Info"
        Write-Status "Destination server collation: $destServerCollation" "Info"
        
        $collationIssues = @()
        
        # Check server-level collation
        if ($sourceServerCollation -ne $destServerCollation) {
            $warning = "Server collation mismatch: Source ($sourceServerCollation) vs Destination ($destServerCollation)"
            $collationIssues += $warning
            if (-not $IgnoreWarnings) {
                Write-Status $warning "Warning"
                Write-Status "This may cause issues with system objects, temporary tables, and cross-database queries" "Warning"
            }
        }
        else {
            Write-Status "Server collations match - OK" "Success"
        }
        
        # Check database-level collations
        foreach ($database in $Databases) {
            try {
                $dbCollation = $database.Collation
                if ($dbCollation -ne $destServerCollation) {
                    $warning = "Database '$($database.Name)' collation ($dbCollation) differs from destination server ($destServerCollation)"
                    $collationIssues += $warning
                    if (-not $IgnoreWarnings) {
                        Write-Status $warning "Warning"
                    }
                }
            }
            catch {
                Write-Status "Could not check collation for database: $($database.Name)" "Warning"
            }
        }
        
        if ($collationIssues.Count -eq 0) {
            Write-Status "No collation compatibility issues detected" "Success"
        }
        else {
            Write-Status "Found $($collationIssues.Count) collation compatibility issues" "Warning"
            if (-not $IgnoreWarnings) {
                Write-Status "Consider the following recommendations:" "Info"
                Write-Status "  1. Test applications thoroughly after migration" "Info"
                Write-Status "  2. Review queries that use string comparisons" "Info"
                Write-Status "  3. Check temporary table operations" "Info"
                Write-Status "  4. Validate cross-database joins and queries" "Info"
                Write-Status "Use -IgnoreCollationWarnings to suppress these warnings" "Info"
            }
        }
        
        return $collationIssues
    }
    catch {
        Write-Status "Error checking collation compatibility: $($_.Exception.Message)" "Warning"
        return @()
    }
}

# Function to get user databases
function Get-UserDatabases {
    param(
        [string]$Instance,
        [PSCredential]$Credential,
        [string[]]$IncludeDatabases,
        [string[]]$ExcludeDatabases,
        [bool]$ExcludeSystemDatabases = $true,
        [bool]$IncludeAllUserDatabases = $false
    )
    
    try {
        Write-Status "Retrieving databases from: $Instance" "Info"
        
        $connectionParams = @{
            SqlInstance = $Instance
        }
        
        if ($Credential) {
            $connectionParams.SqlCredential = $Credential
        }
        
        # Get all databases
        $allDatabases = Get-DbaDatabase @connectionParams
        
        # Filter system databases if requested
        if ($ExcludeSystemDatabases) {
            Write-Status "Excluding system databases" "Info"
            $allDatabases = $allDatabases | Where-Object { 
                $_.Name -notin @('master', 'model', 'msdb', 'tempdb', 'distribution', 'reportserver', 'reportservertempdb') 
            }
        }
        else {
            Write-Status "Including system databases (ExcludeSystemDatabases = false)" "Warning"
        }
        
        # Filter based on include/exclude parameters
        if ($IncludeAllUserDatabases) {
            Write-Status "Including all user databases (IncludeAllUserDatabases = true)" "Info"
            $databases = $allDatabases
        }
        elseif ($IncludeDatabases) {
            $databases = $allDatabases | Where-Object { $_.Name -in $IncludeDatabases }
        }
        else {
            $databases = $allDatabases
        }
        
        if ($ExcludeDatabases) {
            $databases = $databases | Where-Object { $_.Name -notin $ExcludeDatabases }
        }
        
        $databaseType = if ($ExcludeSystemDatabases) { "user" } else { "all" }
        Write-Status "Found $($databases.Count) $databaseType databases to export" "Success"
        foreach ($db in $databases) {
            $sizeGB = [math]::Round($db.Size/1MB, 2)
            $dbType = if ($db.Name -in @('master', 'model', 'msdb', 'tempdb')) { " [SYSTEM]" } else { "" }
            Write-Status "  - $($db.Name) (Size: ${sizeGB} MB)$dbType" "Info"
        }
        
        return $databases
    }
    catch {
        Write-Status "Error retrieving databases: $($_.Exception.Message)" "Error"
        return @()
    }
}

# Function to backup databases
function Backup-UserDatabases {
    param(
        [string]$Instance,
        [PSCredential]$Credential,
        [object[]]$Databases,
        [string]$BackupPath
    )
    
    $backupResults = @()
    
    foreach ($database in $Databases) {
        try {
            Write-Status "Backing up database: $($database.Name)" "Info"
            
            $backupFile = Join-Path $BackupPath "$($database.Name)_$(Get-Date -Format 'yyyyMMdd_HHmmss').bak"
            
            $backupParams = @{
                SqlInstance = $Instance
                Database = $database.Name
                Path = $backupFile
                Type = 'Full'
                CompressBackup = $true
            }
            
            if ($Credential) {
                $backupParams.SqlCredential = $Credential
            }
            
            $backup = Backup-DbaDatabase @backupParams
            
            if ($backup) {
                Write-Status "Successfully backed up $($database.Name) to $backupFile" "Success"
                $backupResults += @{
                    DatabaseName = $database.Name
                    BackupFile = $backupFile
                    Success = $true
                    Size = (Get-Item $backupFile).Length
                }
            }
            else {
                Write-Status "Failed to backup database: $($database.Name)" "Error"
                $backupResults += @{
                    DatabaseName = $database.Name
                    BackupFile = $null
                    Success = $false
                    Error = "Backup operation failed"
                }
            }
        }
        catch {
            Write-Status "Error backing up database $($database.Name): $($_.Exception.Message)" "Error"
            $backupResults += @{
                DatabaseName = $database.Name
                BackupFile = $null
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    return $backupResults
}

# Function to restore databases
function Restore-UserDatabases {
    param(
        [string]$Instance,
        [PSCredential]$Credential,
        [object[]]$BackupResults,
        [bool]$OverwriteExisting
    )
    
    $restoreResults = @()
    
    foreach ($backup in $BackupResults) {
        if (-not $backup.Success) {
            Write-Status "Skipping restore for $($backup.DatabaseName) - backup failed" "Warning"
            continue
        }
        
        try {
            Write-Status "Restoring database: $($backup.DatabaseName)" "Info"
            
            $restoreParams = @{
                SqlInstance = $Instance
                Path = $backup.BackupFile
                DatabaseName = $backup.DatabaseName
            }
            
            if ($Credential) {
                $restoreParams.SqlCredential = $Credential
            }
            
            if ($OverwriteExisting) {
                $restoreParams.WithReplace = $true
            }
            
            $restore = Restore-DbaDatabase @restoreParams
            
            if ($restore) {
                Write-Status "Successfully restored database: $($backup.DatabaseName)" "Success"
                $restoreResults += @{
                    DatabaseName = $backup.DatabaseName
                    Success = $true
                }
            }
            else {
                Write-Status "Failed to restore database: $($backup.DatabaseName)" "Error"
                $restoreResults += @{
                    DatabaseName = $backup.DatabaseName
                    Success = $false
                    Error = "Restore operation failed"
                }
            }
        }
        catch {
            Write-Status "Error restoring database $($backup.DatabaseName): $($_.Exception.Message)" "Error"
            $restoreResults += @{
                DatabaseName = $backup.DatabaseName
                Success = $false
                Error = $_.Exception.Message
            }
        }
    }
    
    return $restoreResults
}

# Function to export logins
function Export-SqlLogins {
    param(
        [string]$SourceInstance,
        [string]$DestinationInstance,
        [PSCredential]$SourceCredential,
        [PSCredential]$DestinationCredential
    )
    
    try {
        Write-Status "Exporting SQL Server logins" "Info"
        
        $copyParams = @{
            Source = $SourceInstance
            Destination = $DestinationInstance
        }
        
        if ($SourceCredential) {
            $copyParams.SourceSqlCredential = $SourceCredential
        }
        
        if ($DestinationCredential) {
            $copyParams.DestinationSqlCredential = $DestinationCredential
        }
        
        $loginResults = Copy-DbaLogin @copyParams
        
        Write-Status "Successfully exported $($loginResults.Count) logins" "Success"
        return $true
    }
    catch {
        Write-Status "Error exporting logins: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Function to export SQL Agent jobs
function Export-SqlJobs {
    param(
        [string]$SourceInstance,
        [string]$DestinationInstance,
        [PSCredential]$SourceCredential,
        [PSCredential]$DestinationCredential
    )
    
    try {
        Write-Status "Exporting SQL Server Agent jobs" "Info"
        
        $copyParams = @{
            Source = $SourceInstance
            Destination = $DestinationInstance
        }
        
        if ($SourceCredential) {
            $copyParams.SourceSqlCredential = $SourceCredential
        }
        
        if ($DestinationCredential) {
            $copyParams.DestinationSqlCredential = $DestinationCredential
        }
        
        $jobResults = Copy-DbaAgentJob @copyParams
        
        Write-Status "Successfully exported $($jobResults.Count) SQL Agent jobs" "Success"
        return $true
    }
    catch {
        Write-Status "Error exporting SQL Agent jobs: $($_.Exception.Message)" "Error"
        return $false
    }
}

# Function to export linked servers
function Export-LinkedServers {
    param(
        [string]$SourceInstance,
        [string]$DestinationInstance,
        [PSCredential]$SourceCredential,
        [PSCredential]$DestinationCredential
    )
    
    try {
        Write-Status "Exporting linked servers" "Info"
        
        $copyParams = @{
            Source = $SourceInstance
            Destination = $DestinationInstance
        }
        
        if ($SourceCredential) {
            $copyParams.SourceSqlCredential = $SourceCredential
        }
        
        if ($DestinationCredential) {
            $copyParams.DestinationSqlCredential = $DestinationCredential
        }
        
        $linkedServerResults = Copy-DbaLinkedServer @copyParams
        
        Write-Status "Successfully exported $($linkedServerResults.Count) linked servers" "Success"
        return $true
    }
    catch {
        Write-Status "Error exporting linked servers: $($_.Exception.Message)" "Error"
        return $false
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
    $sourceConnection = Test-SqlConnection -Instance $SourceInstance -Credential $SourceCredential -Type "source"
    if (-not $sourceConnection) {
        Write-Status "Cannot proceed without source server connection" "Error"
        exit 1
    }
}

if (-not $BackupOnly) {
    $destinationConnection = Test-SqlConnection -Instance $DestinationInstance -Credential $DestinationCredential -Type "destination"
    if (-not $destinationConnection) {
        Write-Status "Cannot proceed without destination server connection" "Error"
        exit 1
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
    $backupResults = Backup-UserDatabases -Instance $SourceInstance -Credential $SourceCredential -Databases $databasesToExport -BackupPath $ExportPath
    
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
