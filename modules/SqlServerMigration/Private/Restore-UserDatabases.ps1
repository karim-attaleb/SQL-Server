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
