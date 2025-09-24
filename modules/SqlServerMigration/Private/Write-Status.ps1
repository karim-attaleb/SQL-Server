function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    # Console output with colors
    switch ($Status) {
        "Success" { Write-Host "✓ $Message" -ForegroundColor Green }
        "Warning" { Write-Host "⚠ $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "✗ $Message" -ForegroundColor Red }
        "Info" { Write-Host "ℹ $Message" -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
    
    # File logging if LogPath is specified
    if ($script:LogPath -and (Test-Path (Split-Path $script:LogPath -Parent))) {
        $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
        $logEntry = "[$timestamp] [$Status] $Message"
        try {
            Add-Content -Path $script:LogPath -Value $logEntry -Encoding UTF8
        }
        catch {
            Write-Warning "Failed to write to log file: $($_.Exception.Message)"
        }
    }
    
    # Windows Event Log if enabled
    if ($script:EnableEventLogging) {
        try {
            # Map status to event log entry type
            $entryType = switch ($Status) {
                "Success" { "Information" }
                "Warning" { "Warning" }
                "Error" { "Error" }
                "Info" { "Information" }
                default { "Information" }
            }
            
            # Map status to event ID ranges
            $eventId = switch ($Status) {
                "Success" { 1001 }
                "Warning" { 2001 }
                "Error" { 3001 }
                "Info" { 1000 }
                default { 1000 }
            }
            
            # Ensure event source exists
            if (-not [System.Diagnostics.EventLog]::SourceExists($script:EventLogSource)) {
                try {
                    New-EventLog -LogName "Application" -Source $script:EventLogSource
                }
                catch {
                    # If we can't create the source, fall back to a generic one
                    $script:EventLogSource = "Application"
                }
            }
            
            # Write to event log
            Write-EventLog -LogName "Application" -Source $script:EventLogSource -EntryType $entryType -EventId $eventId -Message $Message
        }
        catch {
            # Silently continue if event logging fails to avoid disrupting the main process
        }
    }
}
