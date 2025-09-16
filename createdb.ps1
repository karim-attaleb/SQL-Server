# Create database
if ($PSCmdlet.ShouldProcess("Database $Database", "Create database")) {
    $primaryFile = $dataFiles[0]

    # Create file specifications
    $fileSpec = @()
    foreach ($i in 0..($optimalFileCount-1)) {
        $file = $dataFiles[$i]
        $fileSpec += @{
            Name = $file.Name
            FileName = $file.FileName
            Size = $file.Size
            Growth = $file.Growth
        }
    }

    # Define log file parameters
    $logFileName = "$Database_log.ldf"
    $logFilePath = "$logPath\$logFileName"

    $newDbParams = @{
        SqlInstance = $SqlInstance
        Name = $Database
        File = $fileSpec
        LogFile = @{
            Name = "$Database_log"  # Logical name for the log file
            FileName = $logFilePath  # Physical path to the log file
            Size = (Convert-SizeToInt -SizeString $LogSize)
            Growth = (Convert-SizeToInt -SizeString $LogGrowth)
        }
        TrustServerCertificate = $true
    }

    try {
        $newDb = New-DbaDatabase @newDbParams
        Write-Log -Message "Successfully created database: $Database" -Level Success

        # Set database owner to SA
        $db = Get-DbaDatabase -SqlInstance $SqlInstance -Database $Database
        if ($db.Owner -ne 'sa') {
            Set-DbaDatabaseOwner -SqlInstance $SqlInstance -Database $Database -TargetLogin 'sa'
            Write-Log -Message "Changed database owner to SA" -Level Success
        }

        # Enable Query Store for SQL 2016+
        $productVersion = $server.VersionMajor
        if ($productVersion -ge 13) {
            $queryStoreConfig = @{
                SqlInstance = $SqlInstance
                Database = $Database
                State = 'ReadWrite'
                StaleQueryThreshold = [timespan]::FromDays(31)
                CaptureMode = 'Auto'
                MaxStorageSize = 100
                DataFlushInterval = [timespan]::FromSeconds(900)
                SizeBasedCleanupMode = 'Auto'
                MaxPlansPerQuery = 100
            }
            Set-DbaDbQueryStoreOption @queryStoreConfig
            Write-Log -Message "Enabled Query Store for database: $Database" -Level Success
        }
    }
    catch {
        Write-Log -Message "Failed to create database: $($_.Exception.Message)" -Level Error
        throw
    }
}
else {
    Write-Log -Message "[WHATIF] Would create database: $Database" -Level Info
}
