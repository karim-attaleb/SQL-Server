function Export-SqlJobs {
    param(
        [string]$SourceInstance,
        [string]$DestinationInstance,
        [PSCredential]$SourceCredential,
        [PSCredential]$DestinationCredential
    )
    
    try {
        Write-Status "Exporting SQL Server Agent jobs" "Info"
        
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
        
        $jobResults = Copy-DbaAgentJob @copyParams
        
        Write-Status "Successfully exported $($jobResults.Count) SQL Agent jobs" "Success"
        return $true
    }
    catch {
        Write-Status "Error exporting SQL Agent jobs: $($_.Exception.Message)" "Error"
        return $false
    }
}
