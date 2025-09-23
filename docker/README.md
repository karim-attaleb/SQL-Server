# Docker Testing Environment for SQL Server Migration Tool

This directory contains Docker configurations to test the SQL Server Instance Upgrade Tool in a containerized environment with actual SQL Server instances and PowerShell.

## Prerequisites

- Docker Desktop with Windows containers support
- At least 8GB RAM available for containers
- Windows 10/11 or Windows Server 2019+ (for Windows containers)

## Quick Start

1. **Build and start the containers:**
   ```bash
   cd docker
   docker-compose up -d
   ```

2. **Wait for SQL Server containers to start (about 2-3 minutes):**
   ```bash
   docker-compose logs -f sqlserver-source
   docker-compose logs -f sqlserver-destination
   ```

3. **Run the test script:**
   ```bash
   docker exec -it powershell-test pwsh -File C:\Scripts\test-script.ps1
   ```

4. **Interactive testing:**
   ```bash
   docker exec -it powershell-test pwsh
   ```

## Container Architecture

### SQL Server Containers
- **sql-source**: Source SQL Server 2022 instance (port 1433)
- **sql-destination**: Destination SQL Server 2022 instance (port 1434)
- Both use SA authentication with password: `TestPassword123!`

### PowerShell Test Container
- **powershell-test**: Windows PowerShell with dbatools module
- Contains all migration scripts and documentation
- Connected to both SQL Server instances via Docker network

## Test Scenarios

### 1. Basic Connectivity Test
```powershell
# Inside powershell-test container
Import-Module dbatools
Connect-DbaInstance -SqlInstance "sql-source,1433" -SqlCredential (Get-Credential)
```

### 2. Event Log Testing
```powershell
# Test Event Log functionality
.\Export-SqlServerInstance.ps1 -SourceInstance "sql-source,1433" -DestinationInstance "sql-destination,1433" -ExportPath "C:\Backups" -EnableEventLogging -WhatIf
```

### 3. Encryption Testing
```powershell
# Test with encryption
.\Export-SqlServerInstance.ps1 -SourceInstance "sql-source,1433" -DestinationInstance "sql-destination,1433" -ExportPath "C:\Backups" -EncryptConnections -BackupEncryptionAlgorithm "AES256" -BackupEncryptionCertificate "TestBackupCert" -WhatIf
```

### 4. Full Migration Test
```powershell
# Complete migration with all features
.\Export-SqlServerInstance.ps1 -SourceInstance "sql-source,1433" -DestinationInstance "sql-destination,1433" -ExportPath "C:\Backups" -DatabaseNames @("TestMigrationDB") -IncludeLogins -EnableEventLogging -EventLogSource "TestMigration"
```

## Verification Commands

### Check Event Log Entries
```powershell
Get-WinEvent -FilterHashtable @{LogName='Application'; ProviderName='SQLMigrationTest'} -MaxEvents 10
```

### Verify Database Migration
```powershell
Get-DbaDatabase -SqlInstance "sql-destination,1433" -SqlCredential (Get-Credential)
```

### Check Backup Files
```powershell
Get-ChildItem C:\Backups -Recurse
```

## Cleanup

```bash
docker-compose down -v
docker system prune -f
```

## Troubleshooting

### SQL Server Not Starting
- Ensure Docker has enough memory allocated (8GB+)
- Check container logs: `docker-compose logs sqlserver-source`
- Wait longer for SQL Server initialization (can take 3-5 minutes)

### PowerShell Module Issues
- Rebuild containers: `docker-compose build --no-cache`
- Check module installation: `docker exec -it powershell-test pwsh -Command "Get-Module -ListAvailable"`

### Network Connectivity
- Verify containers are on same network: `docker network ls`
- Test connectivity: `docker exec -it powershell-test ping sql-source`

## Performance Notes

- Windows containers require significant resources
- SQL Server containers need time to initialize
- Event Log functionality requires Windows host OS
- Consider using Linux containers with SQL Server on Linux for faster startup times
