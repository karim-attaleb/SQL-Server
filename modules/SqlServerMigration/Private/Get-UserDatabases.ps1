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
