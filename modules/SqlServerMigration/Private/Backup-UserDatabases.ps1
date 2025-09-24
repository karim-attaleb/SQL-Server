function Backup-UserDatabases {
    param(
        [string]$Instance,
        [PSCredential]$Credential,
        [object[]]$Databases,
        [string]$BackupPath,
        [string]$BackupEncryptionAlgorithm,
        [string]$BackupEncryptionCertificate
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
            
            if ($BackupEncryptionAlgorithm -and $BackupEncryptionCertificate) {
                $backupParams.EncryptionAlgorithm = $BackupEncryptionAlgorithm
                $backupParams.EncryptionCertificate = $BackupEncryptionCertificate
                Write-Status "Using backup encryption: $BackupEncryptionAlgorithm with certificate $BackupEncryptionCertificate" "Info"
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
