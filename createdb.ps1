<#
.SYNOPSIS
    Creates and configures SQL Server database with proper security settings and multiple data files
#>
function Invoke-DatabaseCreation {
    [CmdletBinding(SupportsShouldProcess = $true)]
    param(
        [Parameter(Mandatory = $true)]
        [string]$SqlInstance,

        [Parameter(Mandatory = $true)]
        [string]$Database = "DB_MSS0_DEMO",

        [Parameter(Mandatory = $true)]
        [string]$DataDrive,

        [Parameter(Mandatory = $true)]
        [string]$LogDrive,

        [Parameter(Mandatory = $true)]
        [string]$DataSize = "200MB",

        [Parameter(Mandatory = $true)]
        [string]$DataGrowth = "100MB",

        [Parameter(Mandatory = $true)]
        [string]$LogSize = "100MB",

        [Parameter(Mandatory = $true)]
        [string]$LogGrowth = "100MB",

        [string]$FileSizeThreshold = "10GB",

        [ValidateRange(1, 16)]
        [int]$NumberOfDataFiles
    )

    # Set strict mode and bypass certificate validation
    Set-StrictMode -Version Latest
    [System.Net.ServicePointManager]::ServerCertificateValidationCallback = { $true }

    # Function to convert size string to bytes
    function Convert-SizeToBytes {
        param([string]$SizeString)
        if ($SizeString -match '^(\d+)(MB|GB|TB)$') {
            $size = [double]$matches[1]
            $unit = $matches[2]
            switch ($unit) {
                'MB' { return $size * 1MB }
                'GB' { return $size * 1GB }
                'TB' { return $size * 1TB }
                default { return $size }
            }
        }
        return $SizeString
    }

    # Function to convert size string to integer
    function Convert-SizeToInt {
        param([string]$SizeString)
        if ($SizeString -match '^(\d+)(MB|GB|TB)$') {
            $size = [int]$matches[1]
            $unit = $matches[2]
            switch ($unit) {
                'MB' { return $size }
                'GB' { return $size * 1024 }
                'TB' { return $size * 1024 * 1024 }
                default { return $size }
            }
        }
        return $SizeString
    }

    # Function to determine optimal number of data files
    function Get-OptimalDataFileCount {
        param($DataSize, $Threshold, $RequestedCount, $AvailableDrives)

        $dataSizeBytes = Convert-SizeToBytes -SizeString $DataSize
        $thresholdBytes = Convert-SizeToBytes -SizeString $Threshold

        if ($RequestedCount -gt 0) { return [Math]::Min($RequestedCount, $AvailableDrives.Count) }
        if ($dataSizeBytes -lt $thresholdBytes) { return 1 }
        $fileCount = [Math]::Min($AvailableDrives.Count, 8)
        return [Math]::Max($fileCount, 1)
    }

    # Define Write-Log function
    function Write-Log {
        param($Message, [ValidateSet("Info", "Warning", "Error", "Success")]$Level = "Info")
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"
        Write-Host $logEntry -ForegroundColor @{"Info"="White";"Warning"="Yellow";"Error"="Red";"Success"="Green"}[$Level]
        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    }

    try {
        # Setup logging
        $logFile = "DatabaseCreation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        # Import dbatools
        if (-not (Get-Module -Name dbatools -ListAvailable)) {
            Write-Log -Message "Installing dbatools module..." -Level Info
            Install-Module -Name dbatools -Force -AllowClobber -Scope CurrentUser -SkipPublisherCheck
        }
        Import-Module dbatools -ErrorAction Stop
        Write-Log -Message "Successfully imported dbatools module" -Level Info

        # Validate SQL connection
        $connectParams = @{
            SqlInstance = $SqlInstance
            ErrorAction = 'Stop'
            TrustServerCertificate = $true
        }
        $server = Connect-DbaInstance @connectParams
        Write-Log -Message "Successfully connected to SQL instance: $SqlInstance" -Level Success

        # Parse data drives
        $dataDrives = $DataDrive -split ',' | ForEach-Object { $_.Trim() }
        if ($dataDrives.Count -eq 0) {
            Write-Log -Message "No data drives specified. Using default drive." -Level Warning
            $dataDrives = @("G")
        }

        # Determine optimal number of data files
        $optimalFileCount = Get-OptimalDataFileCount -DataSize $DataSize -Threshold $FileSizeThreshold -RequestedCount $NumberOfDataFiles -AvailableDrives $dataDrives
        Write-Log -Message "Using $optimalFileCount data file(s) across $($dataDrives.Count) drive(s)" -Level Info

        # Calculate size per file
        $dataSizeBytes = Convert-SizeToBytes -SizeString $DataSize
        $sizePerFileBytes = [Math]::Ceiling($dataSizeBytes / $optimalFileCount)

        # Check if database already exists
        $existingDb = Get-DbaDatabase -SqlInstance $SqlInstance -Database $Database
        if ($existingDb) {
            Write-Log -Message "Database '$Database' already exists. Skipping creation." -Level Warning
            return $Database
        }

        # Create database with multiple data files
        $dataFiles = @()
        $logPath = "$($LogDrive):\$($server.InstanceName)\log"
        $logFileName = "$Database" + "_log.ldf"  # Properly construct the log file name

        # Create data files configuration
        for ($i = 0; $i -lt $optimalFileCount; $i++) {
            $driveIndex = $i % $dataDrives.Count
            $drive = $dataDrives[$driveIndex]
            $dataPath = "$($drive):\$($server.InstanceName)\data"

            # Ensure directories exist
            if (-not (Test-Path $dataPath)) {
                if ($PSCmdlet.ShouldProcess("$dataPath", "Create data directory")) {
                    New-Item -ItemType Directory -Path $dataPath -Force | Out-Null
                    Write-Log -Message "Created data directory: $dataPath" -Level Info
                }
            }

            $logicalName = if ($i -eq 0) { $Database } else { "$($Database)_$i" }
            $fileName = if ($i -eq 0) { "$Database.mdf" } else { "$Database`_$i.ndf" }

            $dataFiles += @{
                Name = $logicalName
                FileName = "$dataPath\$fileName"
                Size = $sizePerFileBytes / 1MB
                Growth = (Convert-SizeToInt -SizeString $DataGrowth)
            }
        }

        # Ensure log directory exists
        if (-not (Test-Path $logPath)) {
            if ($PSCmdlet.ShouldProcess("$logPath", "Create log directory")) {
                New-Item -ItemType Directory -Path $logPath -Force | Out-Null
                Write-Log -Message "Created log directory: $logPath" -Level Info
            }
        }

        # Create database
        if ($PSCmdlet.ShouldProcess("Database $Database", "Create database")) {
            $primaryFile = $dataFiles[0]

            # Create primary data file
            $fileSpec = @(
                @{
                    Name = $primaryFile.Name
                    FileName = $primaryFile.FileName
                    Size = $primaryFile.Size
                    Growth = $primaryFile.Growth
                }
            )

            # Add secondary files if any
            if ($dataFiles.Count -gt 1) {
                for ($i = 1; $i -lt $dataFiles.Count; $i++) {
                    $file = $dataFiles[$i]
                    $fileSpec += @{
                        Name = $file.Name
                        FileName = $file.FileName
                        Size = $file.Size
                        Growth = $file.Growth
                    }
                }
            }

            $newDbParams = @{
                SqlInstance = $SqlInstance
                Name = $Database
                File = $fileSpec
                LogFile = @{
                    Name = "$Database" + "_log"  # Use string concatenation
                    FileName = "$logPath\$logFileName"
                    Size = (Convert-SizeToInt -SizeString $LogSize)
                    Growth = (Convert-SizeToInt -SizeString $LogGrowth)
                }
                TrustServerCertificate = $true
            }

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
        else {
            Write-Log -Message "[WHATIF] Would create database: $Database" -Level Info
        }

        Write-Log -Message "Database creation completed successfully!" -Level Success
        return $Database
    }
    catch {
        Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level Error
        Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
        exit 1
    }
}
