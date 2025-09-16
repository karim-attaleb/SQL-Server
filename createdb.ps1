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
        LogSize = (Convert-SizeToInt -SizeString $LogSize)
        Growth = (Convert-SizeToInt -SizeString $DataGrowth)
        LogGrowth = (Convert-SizeToInt -SizeString $LogGrowth)
        SkipCACheck = $true
        SkipCNCheck = $true
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
                Growth = (Convert-SizeToInt -SizeString $DataGrowth)
                SkipCACheck = $true
                SkipCNCheck = $true
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
        $newFiles = Get-DbaDbFile -SqlInstance $SqlInstance -Database $Database -SkipCACheck -SkipCNCheck
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
