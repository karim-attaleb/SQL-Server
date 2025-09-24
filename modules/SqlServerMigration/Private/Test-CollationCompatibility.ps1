function Test-CollationCompatibility {
    param(
        [object]$SourceConnection,
        [object]$DestinationConnection,
        [object[]]$Databases,
        [bool]$IgnoreWarnings = $false
    )
    
    try {
        $sourceCollation = $SourceConnection.Collation
        $destinationCollation = $DestinationConnection.Collation
        
        Write-Status "Source server collation: $sourceCollation" "Info"
        Write-Status "Destination server collation: $destinationCollation" "Info"
        
        $collationIssues = @()
        
        if ($sourceCollation -ne $destinationCollation) {
            $collationIssues += "Server collation mismatch: Source ($sourceCollation) vs Destination ($destinationCollation)"
            
            if (-not $IgnoreWarnings) {
                Write-Status "WARNING: Collation mismatch detected between source and destination servers" "Warning"
                Write-Status "Source collation: $sourceCollation" "Warning"
                Write-Status "Destination collation: $destinationCollation" "Warning"
                Write-Status "This may cause issues with:" "Warning"
                Write-Status "  - String comparisons and sorting" "Warning"
                Write-Status "  - Temporary tables and variables" "Warning"
                Write-Status "  - Cross-database queries" "Warning"
                Write-Status "  - Application compatibility" "Warning"
                Write-Status "Consider the following recommendations:" "Info"
                Write-Status "  1. Test applications thoroughly after migration" "Info"
                Write-Status "  2. Review queries that use string comparisons" "Info"
                Write-Status "  3. Check temporary table operations" "Info"
                Write-Status "  4. Validate cross-database joins and queries" "Info"
                Write-Status "Use -IgnoreCollationWarnings to suppress these warnings" "Info"
            }
        }
        
        return $collationIssues
    }
    catch {
        Write-Status "Error checking collation compatibility: $($_.Exception.Message)" "Warning"
        return @()
    }
}
