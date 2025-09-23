# Test Prerequisites for SQL Server Export Tool
# This script tests the environment and prerequisites before running migrations

[CmdletBinding()]
param(
    [string]$SourceInstance,
    [string]$DestinationInstance,
    [PSCredential]$SourceCredential,
    [PSCredential]$DestinationCredential,
    [string]$TestBackupPath = "$env:TEMP\SQLExportTest"
)

Write-Host "SQL Server Export Tool - Prerequisites Test" -ForegroundColor Cyan
Write-Host "=" * 50 -ForegroundColor Cyan

# Function to write colored output
function Write-Status {
    param(
        [string]$Message,
        [string]$Status = "Info"
    )
    
    switch ($Status) {
        "Success" { Write-Host "✓ $Message" -ForegroundColor Green }
        "Warning" { Write-Host "⚠ $Message" -ForegroundColor Yellow }
        "Error" { Write-Host "✗ $Message" -ForegroundColor Red }
        "Info" { Write-Host "ℹ $Message" -ForegroundColor Cyan }
        default { Write-Host $Message }
    }
}

$testResults = @{
    PowerShellVersion = $false
    DbaToolsModule = $false
    SourceConnection = $false
    DestinationConnection = $false
    SourcePermissions = $false
    DestinationPermissions = $false
    NetworkConnectivity = $false
    DiskSpace = $false
}

# Test 1: PowerShell Version
Write-Status "Testing PowerShell version..." "Info"
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Status "PowerShell version $($psVersion.ToString()) - OK" "Success"
    $testResults.PowerShellVersion = $true
}
else {
    Write-Status "PowerShell version $($psVersion.ToString()) - Requires 5.1 or later" "Error"
}

# Test 2: dbatools Module
Write-Status "Testing dbatools module..." "Info"
try {
    Import-Module dbatools -Force -ErrorAction Stop
    $dbaVersion = (Get-Module dbatools).Version
    Write-Status "dbatools version $dbaVersion loaded successfully" "Success"
    $testResults.DbaToolsModule = $true
}
catch {
    Write-Status "Failed to load dbatools module: $($_.Exception.Message)" "Error"
}

# Test 3: Source Instance Connection
if ($SourceInstance) {
    Write-Status "Testing source instance connection: $SourceInstance" "Info"
    try {
        $sourceParams = @{
            SqlInstance = $SourceInstance
        }
        if ($SourceCredential) {
            $sourceParams.SqlCredential = $SourceCredential
        }
        
        $sourceConnection = Connect-DbaInstance @sourceParams -ErrorAction Stop
        Write-Status "Source connection successful - $($sourceConnection.VersionString)" "Success"
        $testResults.SourceConnection = $true
        
        # Test source permissions
        Write-Status "Testing source backup permissions..." "Info"
        try {
            $testDb = Get-DbaDatabase @sourceParams | Where-Object { $_.Name -eq 'master' } | Select-Object -First 1
            if ($testDb) {
                Write-Status "Source backup permissions - OK (can access master database)" "Success"
                $testResults.SourcePermissions = $true
            }
        }
        catch {
            Write-Status "Source backup permissions test failed: $($_.Exception.Message)" "Warning"
        }
    }
    catch {
        Write-Status "Source connection failed: $($_.Exception.Message)" "Error"
    }
}
else {
    Write-Status "No source instance specified - skipping source tests" "Warning"
}

# Test 4: Destination Instance Connection
if ($DestinationInstance) {
    Write-Status "Testing destination instance connection: $DestinationInstance" "Info"
    try {
        $destParams = @{
            SqlInstance = $DestinationInstance
        }
        if ($DestinationCredential) {
            $destParams.SqlCredential = $DestinationCredential
        }
        
        $destConnection = Connect-DbaInstance @destParams -ErrorAction Stop
        Write-Status "Destination connection successful - $($destConnection.VersionString)" "Success"
        $testResults.DestinationConnection = $true
        
        # Check if destination is SQL Server 2022 or compatible
        if ($destConnection.VersionMajor -ge 16) {
            Write-Status "Destination is SQL Server 2022 or later - OK" "Success"
        }
        elseif ($destConnection.VersionMajor -ge 13) {
            Write-Status "Destination is SQL Server 2016+ - Compatible but not 2022" "Warning"
        }
        else {
            Write-Status "Destination is older than SQL Server 2016 - May have compatibility issues" "Warning"
        }
        
        # Test destination permissions
        Write-Status "Testing destination restore permissions..." "Info"
        try {
            $testDb = Get-DbaDatabase @destParams | Where-Object { $_.Name -eq 'master' } | Select-Object -First 1
            if ($testDb) {
                Write-Status "Destination restore permissions - OK (can access master database)" "Success"
                $testResults.DestinationPermissions = $true
            }
        }
        catch {
            Write-Status "Destination restore permissions test failed: $($_.Exception.Message)" "Warning"
        }
    }
    catch {
        Write-Status "Destination connection failed: $($_.Exception.Message)" "Error"
    }
}
else {
    Write-Status "No destination instance specified - skipping destination tests" "Warning"
}

# Test 5: Network Connectivity (if both instances specified)
if ($SourceInstance -and $DestinationInstance -and $testResults.SourceConnection -and $testResults.DestinationConnection) {
    Write-Status "Testing network connectivity between instances..." "Info"
    try {
        # Test if we can perform a simple operation between instances
        $sourceParams = @{ SqlInstance = $SourceInstance }
        $destParams = @{ SqlInstance = $DestinationInstance }
        
        if ($SourceCredential) { $sourceParams.SqlCredential = $SourceCredential }
        if ($DestinationCredential) { $destParams.SqlCredential = $DestinationCredential }
        
        # Simple connectivity test by comparing server names
        $sourceName = (Connect-DbaInstance @sourceParams).Name
        $destName = (Connect-DbaInstance @destParams).Name
        
        if ($sourceName -and $destName) {
            Write-Status "Network connectivity between instances - OK" "Success"
            $testResults.NetworkConnectivity = $true
        }
    }
    catch {
        Write-Status "Network connectivity test failed: $($_.Exception.Message)" "Warning"
    }
}

# Test 6: Disk Space
Write-Status "Testing disk space for backup operations..." "Info"
try {
    if (-not (Test-Path $TestBackupPath)) {
        New-Item -ItemType Directory -Path $TestBackupPath -Force | Out-Null
    }
    
    $drive = Split-Path $TestBackupPath -Qualifier
    $diskSpace = Get-CimInstance -ClassName Win32_LogicalDisk | Where-Object { $_.DeviceID -eq $drive }
    
    if ($diskSpace) {
        $freeSpaceGB = [math]::Round($diskSpace.FreeSpace / 1GB, 2)
        $totalSpaceGB = [math]::Round($diskSpace.Size / 1GB, 2)
        
        Write-Status "Backup drive $drive - Free: ${freeSpaceGB}GB / Total: ${totalSpaceGB}GB" "Info"
        
        if ($freeSpaceGB -gt 10) {
            Write-Status "Sufficient disk space available" "Success"
            $testResults.DiskSpace = $true
        }
        else {
            Write-Status "Low disk space - consider using a different backup location" "Warning"
        }
    }
}
catch {
    Write-Status "Disk space test failed: $($_.Exception.Message)" "Warning"
}

# Test 7: Additional dbatools functionality
Write-Status "Testing additional dbatools functionality..." "Info"
try {
    # Test if we can enumerate databases (if source is available)
    if ($testResults.SourceConnection) {
        $sourceParams = @{ SqlInstance = $SourceInstance }
        if ($SourceCredential) { $sourceParams.SqlCredential = $SourceCredential }
        
        $databases = Get-DbaDatabase @sourceParams | Where-Object { 
            $_.Name -notin @('master', 'model', 'msdb', 'tempdb') 
        }
        
        Write-Status "Found $($databases.Count) user databases on source instance" "Info"
        
        if ($databases.Count -gt 0) {
            Write-Status "Sample databases:" "Info"
            $databases | Select-Object -First 5 | ForEach-Object {
                $sizeGB = [math]::Round($_.Size / 1MB, 2)
                Write-Status "  - $($_.Name) (${sizeGB} MB)" "Info"
            }
        }
    }
}
catch {
    Write-Status "Database enumeration test failed: $($_.Exception.Message)" "Warning"
}

# Test 8: Security and Permissions
Write-Status "Testing security context..." "Info"
$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
$isAdmin = ([Security.Principal.WindowsPrincipal] $currentUser).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")

if ($isAdmin) {
    Write-Status "Running as Administrator - OK" "Success"
}
else {
    Write-Status "Not running as Administrator - some operations may require elevation" "Warning"
}

Write-Status "Current user: $($currentUser.Name)" "Info"

# Summary Report
Write-Host "`n" -NoNewline
Write-Status "Test Summary Report" "Info"
Write-Host "=" * 30 -ForegroundColor Cyan

$passedTests = ($testResults.Values | Where-Object { $_ -eq $true }).Count
$totalTests = $testResults.Count

Write-Status "Tests Passed: $passedTests / $totalTests" "Info"

foreach ($test in $testResults.GetEnumerator()) {
    $status = if ($test.Value) { "Success" } else { "Error" }
    Write-Status "$($test.Key): $($test.Value)" $status
}

# Recommendations
Write-Host "`nRecommendations:" -ForegroundColor Yellow

if (-not $testResults.PowerShellVersion) {
    Write-Host "• Upgrade to PowerShell 5.1 or later" -ForegroundColor White
}

if (-not $testResults.DbaToolsModule) {
    Write-Host "• Install dbatools module: Install-Module dbatools -Force" -ForegroundColor White
}

if (-not $testResults.SourceConnection) {
    Write-Host "• Verify source SQL Server instance name and credentials" -ForegroundColor White
    Write-Host "• Check network connectivity and firewall settings" -ForegroundColor White
}

if (-not $testResults.DestinationConnection) {
    Write-Host "• Verify destination SQL Server instance name and credentials" -ForegroundColor White
    Write-Host "• Ensure SQL Server 2022 is properly installed and configured" -ForegroundColor White
}

if (-not $testResults.SourcePermissions -or -not $testResults.DestinationPermissions) {
    Write-Host "• Ensure SQL Server login has backup/restore permissions" -ForegroundColor White
    Write-Host "• Consider using sysadmin role for migration operations" -ForegroundColor White
}

if (-not $testResults.DiskSpace) {
    Write-Host "• Free up disk space or use a different backup location" -ForegroundColor White
    Write-Host "• Consider using network storage for large migrations" -ForegroundColor White
}

# Final recommendation
Write-Host "`nOverall Status:" -ForegroundColor Yellow
if ($passedTests -eq $totalTests) {
    Write-Status "All tests passed - Ready for migration!" "Success"
}
elseif ($passedTests -ge ($totalTests * 0.7)) {
    Write-Status "Most tests passed - Migration possible with caution" "Warning"
}
else {
    Write-Status "Several tests failed - Address issues before migration" "Error"
}

# Cleanup
if (Test-Path $TestBackupPath) {
    Remove-Item $TestBackupPath -Recurse -Force -ErrorAction SilentlyContinue
}

Write-Host "`nTest completed. Review the results above before proceeding with migration." -ForegroundColor Cyan
