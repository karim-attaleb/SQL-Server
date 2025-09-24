function Test-EncryptionSettings {
    param(
        [object]$Connection,
        [string]$BackupEncryptionAlgorithm,
        [string]$BackupEncryptionCertificate
    )
    
    $validationResults = @{
        BackupEncryptionValid = $true
        ConnectionEncryptionValid = $true
        Warnings = @()
    }
    
    if ($BackupEncryptionAlgorithm -and -not $BackupEncryptionCertificate) {
        $validationResults.BackupEncryptionValid = $false
        $validationResults.Warnings += "BackupEncryptionAlgorithm specified but BackupEncryptionCertificate is missing"
    }
    
    if ($BackupEncryptionCertificate -and -not $BackupEncryptionAlgorithm) {
        $validationResults.BackupEncryptionValid = $false
        $validationResults.Warnings += "BackupEncryptionCertificate specified but BackupEncryptionAlgorithm is missing"
    }
    
    if ($BackupEncryptionCertificate -and $Connection) {
        try {
            $certificateExists = Get-DbaCertificate -SqlInstance $Connection -Certificate $BackupEncryptionCertificate
            if (-not $certificateExists) {
                $validationResults.BackupEncryptionValid = $false
                $validationResults.Warnings += "Backup encryption certificate '$BackupEncryptionCertificate' not found on source server"
            }
        }
        catch {
            $validationResults.Warnings += "Could not verify backup encryption certificate: $($_.Exception.Message)"
        }
    }
    
    return $validationResults
}
