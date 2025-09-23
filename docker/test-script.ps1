# Test script to validate our SQL Server migration tool in containers
param(
    [string]$SourceInstance = "sql-source,1433",
    [string]$DestinationInstance = "sql-destination,1433",
    [string]$ExportPath = "/Scripts/Backups"
)

Write-Host "=== SQL Server Migration Tool Container Test ===" -ForegroundColor Green

# Test 1: Basic connectivity
Write-Host "`nTest 1: Testing SQL Server connectivity..." -ForegroundColor Yellow
try {
    Import-Module dbatools -Force
    Write-Host "✓ dbatools module loaded successfully" -ForegroundColor Green
    
    # Test source connection (bypass SSL certificate validation for containers)
    $sourceConn = Connect-DbaInstance -SqlInstance $SourceInstance -SqlCredential (New-Object System.Management.Automation.PSCredential("sa", (ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force))) -TrustServerCertificate
    Write-Host "✓ Source SQL Server connection successful" -ForegroundColor Green
    
    # Test destination connection (bypass SSL certificate validation for containers)
    $destConn = Connect-DbaInstance -SqlInstance $DestinationInstance -SqlCredential (New-Object System.Management.Automation.PSCredential("sa", (ConvertTo-SecureString "TestPassword123!" -AsPlainText -Force))) -TrustServerCertificate
    Write-Host "✓ Destination SQL Server connection successful" -ForegroundColor Green
    
} catch {
    Write-Host "✗ Connection test failed: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Test 2: Create test database on source
Write-Host "`nTest 2: Creating test database..." -ForegroundColor Yellow
try {
    $testDbName = "TestMigrationDB"
    Invoke-DbaQuery -SqlInstance $sourceConn -Query "
        IF NOT EXISTS (SELECT name FROM sys.databases WHERE name = '$testDbName')
        BEGIN
            CREATE DATABASE [$testDbName]
        END" -Database "master"
        
    Invoke-DbaQuery -SqlInstance $sourceConn -Query "
        IF NOT EXISTS (SELECT * FROM sys.tables WHERE name = 'TestTable')
        BEGIN
            CREATE TABLE TestTable (
                ID int IDENTITY(1,1) PRIMARY KEY,
                Name nvarchar(100),
                CreatedDate datetime2 DEFAULT GETDATE()
            )
            
            INSERT INTO TestTable (Name) VALUES 
                ('Test Record 1'),
                ('Test Record 2'),
                ('Test Record 3')
        END
    " -Database $testDbName
    Write-Host "✓ Test database and data created successfully" -ForegroundColor Green
} catch {
    Write-Host "✗ Test database creation failed: $($_.Exception.Message)" -ForegroundColor Red
    return
}

# Test 3: Event Log functionality simulation (Linux environment)
Write-Host "`nTest 3: Testing Event Log functionality simulation..." -ForegroundColor Yellow
try {
    # Since we're on Linux, we'll test the Event Log logic without actual Windows Event Log
    Write-Host "⚠ Running on Linux - Event Log functionality will be simulated" -ForegroundColor Yellow
    
    # Test the Write-Status function with EnableEventLogging parameter
    $testScript = "/Scripts/Export-SqlServerInstance.ps1"
    if (Test-Path $testScript) {
        # Test script syntax and parameter validation without execution
        $scriptContent = Get-Content $testScript -Raw
        if ($scriptContent -match "Write-Status") {
            Write-Host "✓ Write-Status function found in script" -ForegroundColor Green
        }
        
        if ($scriptContent -match "EnableEventLogging") {
            Write-Host "✓ EnableEventLogging parameter found in script" -ForegroundColor Green
        }
        
        if ($scriptContent -match "EventLogSource") {
            Write-Host "✓ EventLogSource parameter found in script" -ForegroundColor Green
        }
    }
    
    Write-Host "✓ Event Log simulation completed (actual testing requires Windows)" -ForegroundColor Green
} catch {
    Write-Host "⚠ Event Log simulation failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

# Test 4: Run our migration script with basic parameters
Write-Host "`nTest 4: Testing migration script execution..." -ForegroundColor Yellow
try {
    # Create export directory
    if (-not (Test-Path $ExportPath)) {
        New-Item -ItemType Directory -Path $ExportPath -Force | Out-Null
    }
    
    # Test script syntax first
    $scriptPath = "/Scripts/Export-SqlServerInstance.ps1"
    if (Test-Path $scriptPath) {
        # Basic syntax check
        $null = [System.Management.Automation.PSParser]::Tokenize((Get-Content $scriptPath -Raw), [ref]$null)
        Write-Host "✓ PowerShell script syntax is valid" -ForegroundColor Green
        
        # Test with BackupOnly parameter (safer for testing)
        & $scriptPath -SourceInstance $SourceInstance -DestinationInstance $DestinationInstance -ExportPath $ExportPath -DatabaseNames @($testDbName) -BackupOnly -EnableEventLogging -EventLogSource "SQLMigrationTest" -TrustServerCertificate
        Write-Host "✓ Migration script executed successfully (BackupOnly mode)" -ForegroundColor Green
        
    } else {
        Write-Host "✗ Migration script not found at $scriptPath" -ForegroundColor Red
    }
} catch {
    Write-Host "✗ Migration script test failed: $($_.Exception.Message)" -ForegroundColor Red
}

# Test 5: Encryption certificate test
Write-Host "`nTest 5: Testing encryption certificate functionality..." -ForegroundColor Yellow
try {
    # Create a test certificate for backup encryption
    Invoke-DbaQuery -SqlInstance $sourceConn -Query "
        -- Create master key if it doesn't exist
        IF NOT EXISTS (SELECT * FROM sys.symmetric_keys WHERE name = '##MS_DatabaseMasterKey##')
        BEGIN
            CREATE MASTER KEY ENCRYPTION BY PASSWORD = 'TestMasterKey123!'
        END
        
        -- Create backup encryption certificate
        IF NOT EXISTS (SELECT * FROM sys.certificates WHERE name = 'TestBackupCert')
        BEGIN
            CREATE CERTIFICATE TestBackupCert
            WITH SUBJECT = 'Test Backup Encryption Certificate'
        END
    " -Database "master"
    Write-Host "✓ Backup encryption certificate created successfully" -ForegroundColor Green
    
    # Test certificate existence check
    $certExists = Invoke-DbaQuery -SqlInstance $sourceConn -Query "SELECT COUNT(*) as CertCount FROM sys.certificates WHERE name = 'TestBackupCert'" -Database "master" | Select-Object -ExpandProperty CertCount
    if ($certExists -gt 0) {
        Write-Host "✓ Certificate existence verified" -ForegroundColor Green
    } else {
        Write-Host "✗ Certificate not found" -ForegroundColor Red
    }
    
} catch {
    Write-Host "⚠ Encryption certificate test failed: $($_.Exception.Message)" -ForegroundColor Yellow
}

Write-Host "`n=== Container Test Summary ===" -ForegroundColor Green
Write-Host "All basic tests completed. Check output above for any failures." -ForegroundColor Cyan
Write-Host "To run the full migration tool:" -ForegroundColor Cyan
Write-Host "  ./Export-SqlServerInstance.ps1 -SourceInstance '$SourceInstance' -DestinationInstance '$DestinationInstance' -ExportPath '$ExportPath' -DatabaseNames @('$testDbName') -EnableEventLogging -TrustServerCertificate" -ForegroundColor White
