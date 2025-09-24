function Test-SqlConnection {
    param(
        [string]$Instance,
        [PSCredential]$Credential,
        [string]$Type,
        [bool]$EncryptConnection = $false,
        [bool]$TrustServerCertificate = $false
    )
    
    try {
        Write-Status "Testing connection to $Type server: $Instance" "Info"
        
        $connectionParams = @{
            SqlInstance = $Instance
        }
        
        if ($Credential) {
            $connectionParams.SqlCredential = $Credential
        }
        
        if ($EncryptConnection) {
            $connectionParams.EncryptConnection = $true
            Write-Status "Using encrypted connection (TLS/SSL)" "Info"
        }
        
        if ($TrustServerCertificate) {
            $connectionParams.TrustServerCertificate = $true
            Write-Status "Trusting server certificate" "Warning"
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
