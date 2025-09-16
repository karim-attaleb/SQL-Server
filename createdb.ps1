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

        # Convert sizes to integers
        $primarySize = [int]($DataSize -replace 'MB', '')
        $logSizeMB = [int]($LogSize -replace 'MB', '')
        $primaryGrowth = [int]($DataGrowth -replace 'MB', '')
        $logGrowthMB = [int]($LogGrowth -replace 'MB', '')

        # Check if database already exists
        $existingDb = Get-DbaDatabase -SqlInstance $SqlInstance -Database $Database
        if ($existingDb) {
            Write-Log -Message "Database '$Database' already exists. Skipping creation." -Level Warning
            return $Database
        }

        # Create database with primary file
        if ($PSCmdlet.ShouldProcess("Database $Database", "Create database")) {
            $primaryDataPath = "$($dataDrives[0]):\$($server.InstanceName)\data\$Database.mdf"
            $logPath = "$($LogDrive):\$($server.InstanceName)\log\$Database_log.ldf"

            # Ensure directories exist
            if (-not (Test-Path "$($dataDrives[0]):\$($server.InstanceName)\data")) {
                New-Item -ItemType Directory -Path "$($dataDrives[0]):\$($server.InstanceName)\data" -Force | Out-Null
                Write-Log -Message "Created data directory: $($dataDrives[0]):\$($server.InstanceName)\data" -Level Info
            }

            if (-not (Test-Path "$($LogDrive):\$($server.InstanceName)\log")) {
                New-Item -ItemType Directory -Path "$($LogDrive):\$($server.InstanceName)\log" -Force | Out-Null
                Write-Log -Message "Created log directory: $($LogDrive):\$($server.InstanceName)\log" -Level Info
            }

            # Create database with exact parameters from dbatools
            $newDbParams = @{
                SqlInstance = $SqlInstance
                Name = $Database
                DataFilePath = $primaryDataPath
                LogFilePath = $logPath
                PrimaryFileSize = $primarySize
                LogSize = $logSizeMB
                PrimaryFileGrowth = $primaryGrowth
                LogGrowth = $logGrowthMB
                SecondaryFileCount = [Math]::Max(0, $NumberOfDataFiles - 1)
                SecondaryFileGrowth = $primaryGrowth
                TrustServerCertificate = $true
            }

            try {
                # Create the database
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

        Write-Log -Message "Database creation completed successfully!" -Level Success
        return $Database
    }
    catch {
        Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level Error
        Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
        exit 1
    }
}
