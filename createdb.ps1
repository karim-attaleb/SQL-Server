<#
.SYNOPSIS
    Creates and configures SQL Server database with proper security settings and multiple data files
.DESCRIPTION
    Idempotent script to create SQL Server 2022 database with multiple data files, Windows authentication logins
    and database roles. Never drops existing objects.
.PARAMETER SqlInstance
    Target SQL Server instance
.PARAMETER Database
    Database name to create/configure
.PARAMETER DataDrive
    Drive letter for data files (comma-separated for multiple drives)
.PARAMETER LogDrive
    Drive letter for log files
.PARAMETER UserDomain
    Windows domain for authentication
.PARAMETER OU
    Organizational unit number
.PARAMETER DataSize
    Total initial data file size (will be distributed across files)
.PARAMETER DataGrowth
    Data file growth size per file
.PARAMETER LogSize
    Initial log file size
.PARAMETER LogGrowth
    Log file growth size
.PARAMETER DataGroup
    Data group identifier
.PARAMETER SubApp
    Sub-application identifier
.PARAMETER EnableDevUser
    Enable developer user (0 or 1)
.PARAMETER EnablePrwUser
    Enable personal read-write user (0 or 1)
.PARAMETER EnableProUser
    Enable personal read-only user (0 or 1)
.PARAMETER EnableFncUser
    Enable functional user (0 or 1)
.PARAMETER EnableAppUser
    Enable application user (0 or 1)
.PARAMETER NumberOfDataFiles
    Number of data files to create (default: based on CPU cores, min 1, max 8)
.PARAMETER FileSizeThreshold
    Size threshold in GB to trigger multiple file creation (default: 10GB)
.EXAMPLE
    Invoke-DatabaseCreation -SqlInstance "S2S005G2\POD07_DEV" -Database "DB_MSS0_DEMO" -DataDrive "G,H" -LogDrive "E" -WhatIf
.EXAMPLE
    Invoke-DatabaseCreation -SqlInstance "S2S005G2\POD07_DEV" -Database "DB_MSS0_DEMO" -DataDrive "G" -LogDrive "E" -NumberOfDataFiles 4
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
        [string]$UserDomain = "TDA001",

        [Parameter(Mandatory = $true)]
        [string]$OU = "1005",

        [Parameter(Mandatory = $true)]
        [string]$DataSize = "200MB",

        [Parameter(Mandatory = $true)]
        [string]$DataGrowth = "100MB",

        [Parameter(Mandatory = $true)]
        [string]$LogSize = "100MB",

        [Parameter(Mandatory = $true)]
        [string]$LogGrowth = "100MB",

        [string]$DataGroup = "MSS",

        [string]$SubApp = "_01",

        [ValidateSet("0", "1")]
        [string]$EnableDevUser = "1",

        [ValidateSet("0", "1")]
        [string]$EnablePrwUser = "1",

        [ValidateSet("0", "1")]
        [string]$EnableProUser = "1",

        [ValidateSet("0", "1")]
        [string]$EnableFncUser = "1",

        [ValidateSet("0", "1")]
        [string]$EnableAppUser = "0",

        [ValidateRange(1, 16)]
        [int]$NumberOfDataFiles,

        [string]$FileSizeThreshold = "10GB"
    )

    # Set strict mode for better error handling
    Set-StrictMode -Version Latest

    # Set execution policy for current process only (doesn't affect system policy)
    $originalExecutionPolicy = Get-ExecutionPolicy -Scope Process
    Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope Process -Force -ErrorAction SilentlyContinue

    # Set culture and UI culture to invariant for consistent behavior across locales
    $originalCulture = [System.Threading.Thread]::CurrentThread.CurrentCulture
    $originalUICulture = [System.Threading.Thread]::CurrentThread.CurrentUICulture
    [System.Threading.Thread]::CurrentThread.CurrentCulture = [System.Globalization.CultureInfo]::InvariantCulture
    [System.Threading.Thread]::CurrentThread.CurrentUICulture = [System.Globalization.CultureInfo]::InvariantCulture

    # Set error action preference
    $ErrorActionPreference = 'Stop'

    # Define Write-Log function
    function Write-Log {
        param(
            [string]$Message,
            [ValidateSet("Info", "Warning", "Error", "Success")]
            [string]$Level = "Info"
        )

        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Level] $Message"

        Write-Host $logEntry -ForegroundColor @{
            "Info" = "White"
            "Warning" = "Yellow"
            "Error" = "Red"
            "Success" = "Green"
        }[$Level]

        Add-Content -Path $logFile -Value $logEntry -Encoding UTF8
    }

    try {
        # Setup logging with culture-invariant timestamp
        $logFile = "DatabaseCreation_$(Get-Date -Format 'yyyyMMdd_HHmmss').log"

        # Import required modules
        try {
            Import-Module dbatools -ErrorAction Stop
            Write-Log -Message "Successfully imported dbatools module" -Level Info
        }
        catch {
            Write-Error "dbatools module is required. Please install with: Install-Module dbatools -Scope CurrentUser -Force"
            exit 1
        }

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

        # Function to determine optimal number of data files
        function Get-OptimalDataFileCount {
            param(
                [string]$DataSize,
                [string]$Threshold,
                [int]$RequestedCount,
                [string[]]$AvailableDrives
            )

            $dataSizeBytes = Convert-SizeToBytes -SizeString $DataSize
            $thresholdBytes = Convert-SizeToBytes -SizeString $Threshold

            # If number of files is explicitly requested, use it
            if ($RequestedCount -gt 0) {
                return [Math]::Min($RequestedCount, $AvailableDrives.Count)
            }

            # If database size is below threshold, use single file
            if ($dataSizeBytes -lt $thresholdBytes) {
                return 1
            }

            # For larger databases, use 1 file per available drive, but max 8
            $fileCount = [Math]::Min($AvailableDrives.Count, 8)

            # Ensure at least 1 file
            return [Math]::Max($fileCount, 1)
        }

        # Log locale information for debugging
        Write-Log -Message "Current culture: $([System.Threading.Thread]::CurrentThread.CurrentCulture)" -Level Info
        Write-Log -Message "Current UI culture: $([System.Threading.Thread]::CurrentThread.CurrentUICulture)" -Level Info

        # Validate SQL connection
        try {
            $server = Connect-DbaInstance -SqlInstance $SqlInstance -ErrorAction Stop
            Write-Log -Message "Successfully connected to SQL instance: $SqlInstance" -Level Success
        }
        catch {
            Write-Log -Message "Failed to connect to SQL instance: $SqlInstance. Error: $($_.Exception.Message)" -Level Error
            exit 1
        }

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

        # Convert back to readable format
        function Format-Bytes {
            param([double]$Bytes)
            if ($Bytes -ge 1TB) { return "$([Math]::Round($Bytes / 1TB, 2))TB" }
            if ($Bytes -ge 1GB) { return "$([Math]::Round($Bytes / 1GB, 2))GB" }
            if ($Bytes -ge 1MB) { return "$([Math]::Round($Bytes / 1MB, 2))MB" }
            return "$Bytes bytes"
        }

        $sizePerFile = Format-Bytes -Bytes $sizePerFileBytes
        Write-Log -Message "Total data size: $DataSize, Size per file: $sizePerFile" -Level Info

        # Main execution
        Write-Log -Message "Starting database creation process for: $Database" -Level Info
        Write-Log -Message "Parameters: DataDrives=$($dataDrives -join ','), LogDrive=$LogDrive, TotalDataSize=$DataSize, Files=$optimalFileCount" -Level Info

        # Check if database already exists
        $existingDb = Get-DbaDatabase -SqlInstance $SqlInstance -Database $Database
        if ($existingDb) {
            Write-Log -Message "Database '$Database' already exists. Skipping creation." -Level Warning

            # Log existing file configuration using dbatools
            $existingFiles = Get-DbaDbFile -SqlInstance $SqlInstance -Database $Database
            Write-Log -Message "Existing database files:" -Level Info
            foreach ($file in $existingFiles) {
                Write-Log -Message "  $($file.Type): $($file.LogicalName) - $($file.PhysicalName) ($($file.Size.Megabyte) MB)" -Level Info
            }
        }
        else {
            # Create database with multiple data files using dbatools
            $dataFiles = @()
            $logPath = "$($LogDrive):\$($server.InstanceName)\log"

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
                    else {
                        Write-Log -Message "[WHATIF] Would create data directory: $dataPath" -Level Info
                    }
                }

                $logicalName = if ($i -eq 0) {
                    $Database
                } else {
                    "$($Database)_$i"
                }

                $fileName = if ($i -eq 0) {
                    "$Database.mdf"
                } else {
                    "$Database`_$i.ndf"
                }

                $dataFiles += @{
                    Name = $logicalName
                    FileName = "$dataPath\$fileName"
                    Size = $sizePerFileBytes / 1MB  # Convert to MB for dbatools
                    Growth = $DataGrowth
                }
            }

            # Ensure log directory exists
            if (-not (Test-Path $logPath)) {
                if ($PSCmdlet.ShouldProcess("$logPath", "Create log directory")) {
                    New-Item -ItemType Directory -Path $logPath -Force | Out-Null
                    Write-Log -Message "Created log directory: $logPath" -Level Info
                }
                else {
                    Write-Log -Message "[WHATIF] Would create log directory: $logPath" -Level Info
                }
            }

            # Create database using dbatools
            try {
                Write-Log -Message "Creating database with $optimalFileCount data file(s) using dbatools..." -Level Info

                # Create primary data file first
                $primaryFile = $dataFiles[0]
                $newDbParams = @{
                    SqlInstance = $SqlInstance
                    Name = $Database
                    DataFilePath = $primaryFile.FileName
                    LogFilePath = "$logPath\$($Database)_log.ldf"
                    Size = $primaryFile.Size
                    LogSize = [int]($LogSize -replace 'MB','')  # Convert "100MB" to 100
                    Growth = $DataGrowth
                    LogGrowth = $LogGrowth
                    EnableException = $true
                }

                if ($PSCmdlet.ShouldProcess("Database $Database", "Create database")) {
                    $newDb = New-DbaDatabase @newDbParams
                    Write-Log -Message "Successfully created database with primary file: $Database" -Level Success
                }
                else {
                    Write-Log -Message "[WHATIF] Would create database: $Database" -Level Info
                }

                # Add secondary data files if any
                if ($dataFiles.Count -gt 1) {
                    for ($i = 1; $i -lt $dataFiles.Count; $i++) {
                        $file = $dataFiles[$i]

                        $addFileParams = @{
                            SqlInstance = $SqlInstance
                            Database = $Database
                            Name = $file.Name
                            FileName = $file.FileName
                            Size = $file.Size
                            Growth = $file.Growth
                            EnableException = $true
                        }

                        if ($PSCmdlet.ShouldProcess("File $($file.Name)", "Add secondary data file")) {
                            $result = Add-DbaDbFile @addFileParams
                            Write-Log -Message "Added secondary data file: $($file.Name) - $($file.FileName)" -Level Success
                        }
                        else {
                            Write-Log -Message "[WHATIF] Would add secondary data file: $($file.Name) - $($file.FileName)" -Level Info
                        }
                    }
                }

                # Log file configuration using dbatools
                if (-not $PSCmdlet.ShouldProcess("Database $Database", "Show file configuration")) {
                    $newFiles = Get-DbaDbFile -SqlInstance $SqlInstance -Database $Database
                    Write-Log -Message "Created database files:" -Level Info
                    foreach ($file in $newFiles) {
                        Write-Log -Message "  $($file.Type): $($file.LogicalName) - $($file.PhysicalName) ($($file.Size.Megabyte) MB)" -Level Info
                    }
                }
            }
            catch {
                Write-Log -Message "Failed to create database using dbatools: $($_.Exception.Message)" -Level Error
                throw
            }
        }

        # Set database owner to SA if not already
        $dbOwner = Get-DbaDbOwner -SqlInstance $SqlInstance -Database $Database
        if ($dbOwner.Owner -ne 'sa') {
            if ($PSCmdlet.ShouldProcess("Database $Database", "Set database owner to SA")) {
                Set-DbaDbOwner -SqlInstance $SqlInstance -Database $Database -TargetLogin 'sa' -Confirm:$false
                Write-Log -Message "Changed database owner to SA" -Level Success
            }
            else {
                Write-Log -Message "[WHATIF] Would change database owner to SA" -Level Info
            }
        }
        else {
            Write-Log -Message "Database owner is already SA" -Level Info
        }

        # Create logins and users
        $loginsToCreate = @()

        if ($EnableDevUser -eq "1" -and $OU -eq "1005") {
            $loginName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_DEV_RW"
            $loginsToCreate += @{Name = $loginName; Type = "Windows"}
        }

        if ($EnableAppUser -eq "1") {
            $loginName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_APP_R1"
            $loginsToCreate += @{Name = $loginName; Type = "Windows"}
        }

        if ($EnableFncUser -eq "1") {
            $loginName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_FNC_RW"
            $loginsToCreate += @{Name = $loginName; Type = "Windows"}
        }

        if ($EnablePrwUser -eq "1") {
            $loginName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_PRS_RW"
            $loginsToCreate += @{Name = $loginName; Type = "Windows"}
        }

        if ($EnableProUser -eq "1") {
            $loginName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_PRS_RO"
            $loginsToCreate += @{Name = $loginName; Type = "Windows"}
        }

        # Create logins if they don't exist using dbatools
        foreach ($login in $loginsToCreate) {
            $existingLogin = Get-DbaLogin -SqlInstance $SqlInstance -Login $login.Name
            if (-not $existingLogin) {
                if ($PSCmdlet.ShouldProcess("Login $($login.Name)", "Create login")) {
                    New-DbaLogin -SqlInstance $SqlInstance -Login $login.Name -Windows -EnableException
                    Write-Log -Message "Created login: $($login.Name)" -Level Success
                }
                else {
                    Write-Log -Message "[WHATIF] Would create login: $($login.Name)" -Level Info
                }
            }
            else {
                Write-Log -Message "Login already exists: $($login.Name)" -Level Info
            }
        }

        # Create db_executor role if it doesn't exist using dbatools
        $dbRoles = Get-DbaDbRole -SqlInstance $SqlInstance -Database $Database
        $executorRole = $dbRoles | Where-Object { $_.Name -eq 'db_executor' }

        if (-not $executorRole) {
            if ($PSCmdlet.ShouldProcess("Database $Database", "Create db_executor role")) {
                try {
                    # Create the role using dbatools
                    $newRole = New-DbaDbRole -SqlInstance $SqlInstance -Database $Database -Role 'db_executor' -EnableException
                    Write-Log -Message "Created db_executor role" -Level Success

                    # Grant EXECUTE permission using dbatools
                    Grant-DbaDbPermission -SqlInstance $SqlInstance -Database $Database -Permission 'EXECUTE' -Role 'db_executor' -EnableException
                    Write-Log -Message "Granted EXECUTE permission to db_executor role" -Level Success
                }
                catch {
                    Write-Log -Message "Failed to create db_executor role: $($_.Exception.Message)" -Level Error
                }
            }
            else {
                Write-Log -Message "[WHATIF] Would create db_executor role" -Level Info
            }
        }
        else {
            Write-Log -Message "db_executor role already exists" -Level Info
        }

        # Create database users and assign roles using dbatools
        $usersToCreate = @()

        if ($EnableDevUser -eq "1" -and $OU -eq "1005") {
            $userName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_DEV_RW"
            $usersToCreate += @{
                Name = $userName
                Login = $userName
                Roles = @("db_owner")
            }
        }

        if ($EnableAppUser -eq "1") {
            $userName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_APP_R1"
            $usersToCreate += @{
                Name = $userName
                Login = $userName
                Roles = @("db_datareader", "db_datawriter", "db_executor")
            }
        }

        if ($EnableFncUser -eq "1") {
            $userName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_FNC_RW"
            $usersToCreate += @{
                Name = $userName
                Login = $userName
                Roles = @("db_datareader", "db_datawriter", "db_executor")
            }
        }

        if ($EnableProUser -eq "1") {
            $userName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_PRS_RO"
            $usersToCreate += @{
                Name = $userName
                Login = $userName
                Roles = @("db_datareader", "db_denydatawriter")
            }
        }

        if ($EnablePrwUser -eq "1") {
            $userName = "$UserDomain\$($OU)_GS_$($DataGroup)0$($SubApp)_PRS_RW"
            $usersToCreate += @{
                Name = $userName
                Login = $userName
                Roles = @("db_datareader", "db_datawriter", "db_executor")
            }
        }

        # Create users and assign roles using dbatools
        foreach ($user in $usersToCreate) {
            $existingUser = Get-DbaDbUser -SqlInstance $SqlInstance -Database $Database -User $user.Name
            if (-not $existingUser) {
                if ($PSCmdlet.ShouldProcess("User $($user.Name)", "Create database user")) {
                    try {
                        New-DbaDbUser -SqlInstance $SqlInstance -Database $Database -Login $user.Login -Username $user.Name -EnableException
                        Write-Log -Message "Created database user: $($user.Name)" -Level Success
                    }
                    catch {
                        Write-Log -Message "Failed to create user $($user.Name): $($_.Exception.Message)" -Level Error
                        continue
                    }
                }
                else {
                    Write-Log -Message "[WHATIF] Would create database user: $($user.Name)" -Level Info
                }
            }
            else {
                Write-Log -Message "Database user already exists: $($user.Name)" -Level Info
            }

            # Assign roles using dbatools
            foreach ($role in $user.Roles) {
                if ($PSCmdlet.ShouldProcess("User $($user.Name)", "Assign role $role")) {
                    try {
                        # Handle db_denydatawriter separately as it's a permission, not a role
                        if ($role -eq 'db_denydatawriter') {
                            # Revoke write permissions for read-only users
                            Revoke-DbaDbPermission -SqlInstance $SqlInstance -Database $Database -User $user.Name -Permission 'INSERT', 'UPDATE', 'DELETE', 'REFERENCES' -EnableException
                            Write-Log -Message "Set read-only permissions for user: $($user.Name)" -Level Success
                        }
                        else {
                            Add-DbaDbRoleMember -SqlInstance $SqlInstance -Database $Database -User $user.Name -Role $role -Confirm:$false -EnableException
                            Write-Log -Message "Added user $($user.Name) to role: $role" -Level Success
                        }
                    }
                    catch {
                        Write-Log -Message "Failed to assign role $role to user $($user.Name): $($_.Exception.Message)" -Level Error
                    }
                }
                else {
                    Write-Log -Message "[WHATIF] Would assign role $role to user $($user.Name)" -Level Info
                }
            }
        }

        # Enable Query Store for SQL 2016+ (including 2022) using dbatools
        $productVersion = $server.VersionMajor
        if ($productVersion -ge 13) { # SQL 2016 = 13, 2022 = 16
            try {
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
                    EnableException = $true
                }

                if ($PSCmdlet.ShouldProcess("Database $Database", "Enable Query Store")) {
                    Set-DbaDbQueryStoreOption @queryStoreConfig
                    Write-Log -Message "Enabled Query Store for database: $Database" -Level Success
                }
                else {
                    Write-Log -Message "[WHATIF] Would enable Query Store for database: $Database" -Level Info
                }
            }
            catch {
                Write-Log -Message "Failed to enable Query Store: $($_.Exception.Message)" -Level Error
            }
        }

        # Display file information using dbatools
        if (-not $PSCmdlet.ShouldProcess("Database $Database", "Show file information")) {
            $fileInfo = Get-DbaDbFile -SqlInstance $SqlInstance -Database $Database
            Write-Log -Message "Database file information:" -Level Info
            foreach ($file in $fileInfo) {
                Write-Log -Message "  $($file.Type): $($file.LogicalName) - $($file.PhysicalName) ($($file.Size.Megabyte) MB)" -Level Info
            }
        }

        Write-Log -Message "Database creation and configuration completed successfully!" -Level Success

    }
    catch {
        Write-Log -Message "Script execution failed: $($_.Exception.Message)" -Level Error
        Write-Log -Message "Stack trace: $($_.ScriptStackTrace)" -Level Error
        exit 1
    }
    finally {
        # Restore original culture settings
        [System.Threading.Thread]::CurrentThread.CurrentCulture = $originalCulture
        [System.Threading.Thread]::CurrentThread.CurrentUICulture = $originalUICulture

        # Restore original execution policy
        Set-ExecutionPolicy -ExecutionPolicy $originalExecutionPolicy -Scope Process -Force -ErrorAction SilentlyContinue

        Write-Log -Message "Script execution completed. Locale settings restored." -Level Info
    }
}

# Call the function with your parameters
$params = @{
    SqlInstance = "S2S005G2\POD07_DEV"
    Database    = "DB_MSS0_DEMO"
    DataDrive   = "G,H"
    LogDrive    = "E"
    UserDomain  = "TDA001"
    OU          = "1005"
    DataSize    = "200MB"
    DataGrowth  = "100MB"
    LogSize     = "100MB"
    LogGrowth   = "100MB"
    Verbose     = $true
}
Invoke-DatabaseCreation @params -WhatIf
