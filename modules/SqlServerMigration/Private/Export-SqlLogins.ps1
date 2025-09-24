function Export-SqlLogins {
    param(
        [string]$SourceInstance,
        [string]$DestinationInstance,
        [PSCredential]$SourceCredential,
        [PSCredential]$DestinationCredential
    )
    
    try {
        Write-Status "Exporting SQL Server logins" "Info"
        
        $copyParams = @{
            Source = $SourceInstance
            Destination = $DestinationInstance
        }
        
        if ($SourceCredential) {
            $copyParams.SourceSqlCredential = $SourceCredential
        }
        
        if ($DestinationCredential) {
            $copyParams.DestinationSqlCredential = $DestinationCredential
        }
        
        $loginResults = Copy-DbaLogin @copyParams
        
        Write-Status "Successfully exported $($loginResults.Count) logins" "Success"
        return $true
    }
    catch {
        Write-Status "Error exporting logins: $($_.Exception.Message)" "Error"
        return $false
    }
}
