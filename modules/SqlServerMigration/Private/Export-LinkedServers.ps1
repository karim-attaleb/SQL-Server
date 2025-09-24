function Export-LinkedServers {
    param(
        [string]$SourceInstance,
        [string]$DestinationInstance,
        [PSCredential]$SourceCredential,
        [PSCredential]$DestinationCredential
    )
    
    try {
        Write-Status "Exporting linked servers" "Info"
        
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
        
        $linkedServerResults = Copy-DbaLinkedServer @copyParams
        
        Write-Status "Successfully exported $($linkedServerResults.Count) linked servers" "Success"
        return $true
    }
    catch {
        Write-Status "Error exporting linked servers: $($_.Exception.Message)" "Error"
        return $false
    }
}
