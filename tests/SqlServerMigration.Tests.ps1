Describe "SqlServerMigration Module Tests" {
    BeforeAll {
        # Import the module for testing
        $ModulePath = Join-Path $PSScriptRoot "..\modules\SqlServerMigration\SqlServerMigration.psd1"
        Import-Module $ModulePath -Force
        
        # Mock dbatools functions to avoid requiring actual SQL Server instances
        Mock Connect-DbaInstance { 
            return [PSCustomObject]@{
                VersionString = "16.0.4215.2"
                Collation = "SQL_Latin1_General_CP1_CI_AS"
                Name = "MockServer"
            }
        }
        
        Mock Get-DbaDatabase {
            return @(
                [PSCustomObject]@{ Name = "TestDB1"; Size = 100 },
                [PSCustomObject]@{ Name = "TestDB2"; Size = 200 },
                [PSCustomObject]@{ Name = "master"; Size = 50 },
                [PSCustomObject]@{ Name = "model"; Size = 25 }
            )
        }
        
        Mock Backup-DbaDatabase { 
            return [PSCustomObject]@{ BackupComplete = $true }
        }
        
        Mock Restore-DbaDatabase { 
            return [PSCustomObject]@{ RestoreComplete = $true }
        }
        
        Mock Copy-DbaLogin { return @() }
        Mock Copy-DbaAgentJob { return @() }
        Mock Copy-DbaLinkedServer { return @() }
        Mock Get-DbaCertificate { return $true }
        
        # Create test directory
        $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
        if (-not (Test-Path $TestPath)) {
            New-Item -ItemType Directory -Path $TestPath -Force | Out-Null
        }
    }
    
    AfterAll {
        # Clean up test directory
        $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
        if (Test-Path $TestPath) {
            Remove-Item -Path $TestPath -Recurse -Force
        }
    }

    Context "UnitTests - Parameter Validation" {
        It "Should have Export-SqlServerInstance function available" {
            Get-Command Export-SqlServerInstance | Should -Not -BeNullOrEmpty
        }
        
        It "Should require SourceInstance parameter" {
            { Export-SqlServerInstance -DestinationInstance "Test" -ExportPath "C:\Test" } | Should -Throw
        }
        
        It "Should require DestinationInstance parameter" {
            { Export-SqlServerInstance -SourceInstance "Test" -ExportPath "C:\Test" } | Should -Throw
        }
        
        It "Should require ExportPath parameter" {
            { Export-SqlServerInstance -SourceInstance "Test" -DestinationInstance "Test" } | Should -Throw
        }
        
        It "Should validate BackupEncryptionAlgorithm parameter" {
            { Export-SqlServerInstance -SourceInstance "Test" -DestinationInstance "Test" -ExportPath "C:\Test" -BackupEncryptionAlgorithm "InvalidAlgorithm" } | Should -Throw
        }
        
        It "Should accept valid BackupEncryptionAlgorithm values" {
            $validAlgorithms = @("AES128", "AES192", "AES256", "TRIPLEDES")
            foreach ($algorithm in $validAlgorithms) {
                { Export-SqlServerInstance -SourceInstance "Test" -DestinationInstance "Test" -ExportPath "C:\Test" -BackupEncryptionAlgorithm $algorithm -WhatIf } | Should -Not -Throw
            }
        }
    }

    Context "UnitTests - Private Function Tests" {
        It "Should have Write-Status function available" {
            { Write-Status -Message "Test" -Status "Info" } | Should -Not -Throw
        }
        
        It "Should have Test-SqlConnection function available" {
            $result = Test-SqlConnection -Instance "MockServer" -Type "source"
            $result | Should -Not -BeNullOrEmpty
            $result.Name | Should -Be "MockServer"
        }
        
        It "Should have Test-EncryptionSettings function available" {
            $mockConnection = [PSCustomObject]@{ Name = "MockServer" }
            $result = Test-EncryptionSettings -Connection $mockConnection -BackupEncryptionAlgorithm "AES256" -BackupEncryptionCertificate "TestCert"
            $result | Should -Not -BeNullOrEmpty
            $result.BackupEncryptionValid | Should -Be $true
        }
        
        It "Should have Test-CollationCompatibility function available" {
            $mockSource = [PSCustomObject]@{ Collation = "SQL_Latin1_General_CP1_CI_AS" }
            $mockDest = [PSCustomObject]@{ Collation = "SQL_Latin1_General_CP1_CI_AS" }
            $result = Test-CollationCompatibility -SourceConnection $mockSource -DestinationConnection $mockDest -Databases @() -IgnoreWarnings $true
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Get-UserDatabases function available" {
            $result = Get-UserDatabases -Instance "MockServer" -ExcludeSystemDatabases $true
            $result | Should -Not -BeNullOrEmpty
            $result.Count | Should -Be 2
            $result[0].Name | Should -Be "TestDB1"
        }
        
        It "Should have Backup-UserDatabases function available" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            $mockDatabases = @([PSCustomObject]@{ Name = "TestDB1" })
            $result = Backup-UserDatabases -Instance "MockServer" -Databases $mockDatabases -BackupPath $TestPath
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Restore-UserDatabases function available" {
            $mockBackupResults = @(@{ DatabaseName = "TestDB1"; BackupFile = "test.bak"; Success = $true })
            $result = Restore-UserDatabases -Instance "MockServer" -BackupResults $mockBackupResults -OverwriteExisting $false
            $result | Should -Not -BeNullOrEmpty
        }
        
        It "Should have Export-SqlLogins function available" {
            $result = Export-SqlLogins -SourceInstance "MockSource" -DestinationInstance "MockDest"
            $result | Should -Be $true
        }
        
        It "Should have Export-SqlJobs function available" {
            $result = Export-SqlJobs -SourceInstance "MockSource" -DestinationInstance "MockDest"
            $result | Should -Be $true
        }
        
        It "Should have Export-LinkedServers function available" {
            $result = Export-LinkedServers -SourceInstance "MockSource" -DestinationInstance "MockDest"
            $result | Should -Be $true
        }
    }

    Context "IntegrationTests - Module Functionality" {
        It "Should import module successfully" {
            $module = Get-Module SqlServerMigration
            $module | Should -Not -BeNullOrEmpty
            $module.Name | Should -Be "SqlServerMigration"
        }
        
        It "Should export only Export-SqlServerInstance function" {
            $module = Get-Module SqlServerMigration
            $module.ExportedFunctions.Keys | Should -Contain "Export-SqlServerInstance"
            $module.ExportedFunctions.Keys.Count | Should -Be 1
        }
        
        It "Should execute Export-SqlServerInstance with BackupOnly mode" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath $TestPath -BackupOnly } | Should -Not -Throw
        }
        
        It "Should handle encryption parameters correctly" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath $TestPath -BackupEncryptionAlgorithm "AES256" -BackupEncryptionCertificate "TestCert" -BackupOnly } | Should -Not -Throw
        }
        
        It "Should handle Event Log parameters correctly" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath $TestPath -EnableEventLogging -EventLogSource "TestSource" -BackupOnly } | Should -Not -Throw
        }
        
        It "Should handle database selection parameters correctly" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath $TestPath -DatabaseNames @("TestDB1") -ExcludeSystemDatabases -BackupOnly } | Should -Not -Throw
        }
        
        It "Should handle connection encryption parameters correctly" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath $TestPath -EncryptConnections -TrustServerCertificate -BackupOnly } | Should -Not -Throw
        }
    }

    Context "IntegrationTests - Error Handling" {
        It "Should handle invalid export path gracefully" {
            Mock New-Item { throw "Access denied" }
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath "Z:\InvalidPath" -BackupOnly } | Should -Throw
        }
        
        It "Should handle connection failures gracefully" {
            Mock Connect-DbaInstance { throw "Connection failed" }
            { Export-SqlServerInstance -SourceInstance "InvalidServer" -DestinationInstance "MockDest" -ExportPath $env:TEMP -BackupOnly } | Should -Throw
        }
        
        It "Should validate encryption settings properly" {
            $TestPath = Join-Path $env:TEMP "SqlServerMigrationTest"
            Mock Get-DbaCertificate { return $null }
            { Export-SqlServerInstance -SourceInstance "MockSource" -DestinationInstance "MockDest" -ExportPath $TestPath -BackupEncryptionAlgorithm "AES256" -BackupEncryptionCertificate "NonExistentCert" -BackupOnly } | Should -Throw
        }
    }
}
