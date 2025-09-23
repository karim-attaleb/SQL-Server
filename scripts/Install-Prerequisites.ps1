# Install Prerequisites for SQL Server Export Tool
# This script installs and configures the required components

[CmdletBinding()]
param(
    [switch]$Force,
    [switch]$SkipModuleUpdate
)

Write-Host "SQL Server Export Tool - Prerequisites Installation" -ForegroundColor Cyan
Write-Host "=" * 60 -ForegroundColor Cyan

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

# Check PowerShell version
Write-Status "Checking PowerShell version..." "Info"
$psVersion = $PSVersionTable.PSVersion
if ($psVersion.Major -ge 5) {
    Write-Status "PowerShell version $($psVersion.ToString()) is supported" "Success"
}
else {
    Write-Status "PowerShell version $($psVersion.ToString()) is not supported. Please upgrade to PowerShell 5.1 or later" "Error"
    exit 1
}

# Check execution policy
Write-Status "Checking PowerShell execution policy..." "Info"
$executionPolicy = Get-ExecutionPolicy
if ($executionPolicy -eq "Restricted") {
    Write-Status "Execution policy is Restricted. Attempting to set to RemoteSigned..." "Warning"
    try {
        Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser -Force
        Write-Status "Execution policy set to RemoteSigned for current user" "Success"
    }
    catch {
        Write-Status "Failed to set execution policy. Please run as Administrator or manually set execution policy" "Error"
        Write-Status "Run: Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser" "Info"
    }
}
else {
    Write-Status "Execution policy is $executionPolicy - OK" "Success"
}

# Check if running as Administrator
$isAdmin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")
if ($isAdmin) {
    Write-Status "Running as Administrator" "Success"
}
else {
    Write-Status "Not running as Administrator - some operations may require elevation" "Warning"
}

# Install NuGet provider if needed
Write-Status "Checking NuGet package provider..." "Info"
$nugetProvider = Get-PackageProvider -Name NuGet -ErrorAction SilentlyContinue
if (-not $nugetProvider) {
    Write-Status "Installing NuGet package provider..." "Info"
    try {
        Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser
        Write-Status "NuGet package provider installed successfully" "Success"
    }
    catch {
        Write-Status "Failed to install NuGet package provider: $($_.Exception.Message)" "Error"
    }
}
else {
    Write-Status "NuGet package provider is already installed" "Success"
}

# Set PSGallery as trusted repository
Write-Status "Configuring PSGallery repository..." "Info"
try {
    $psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
    if ($psGallery.InstallationPolicy -ne "Trusted") {
        Set-PSRepository -Name PSGallery -InstallationPolicy Trusted
        Write-Status "PSGallery repository set as trusted" "Success"
    }
    else {
        Write-Status "PSGallery repository is already trusted" "Success"
    }
}
catch {
    Write-Status "Failed to configure PSGallery repository: $($_.Exception.Message)" "Error"
}

# Install or update dbatools module
Write-Status "Checking dbatools module..." "Info"
$dbatools = Get-Module -Name dbatools -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1

if ($dbatools) {
    Write-Status "dbatools version $($dbatools.Version) is installed" "Success"
    
    if (-not $SkipModuleUpdate) {
        Write-Status "Checking for dbatools updates..." "Info"
        try {
            $latestVersion = Find-Module -Name dbatools | Select-Object -ExpandProperty Version
            if ($latestVersion -gt $dbatools.Version) {
                Write-Status "Newer version $latestVersion available. Updating..." "Info"
                Update-Module -Name dbatools -Force
                Write-Status "dbatools updated to version $latestVersion" "Success"
            }
            else {
                Write-Status "dbatools is up to date" "Success"
            }
        }
        catch {
            Write-Status "Failed to check for updates: $($_.Exception.Message)" "Warning"
        }
    }
}
else {
    Write-Status "Installing dbatools module..." "Info"
    try {
        Install-Module -Name dbatools -Force -AllowClobber -Scope CurrentUser
        $installedVersion = (Get-Module -Name dbatools -ListAvailable | Sort-Object Version -Descending | Select-Object -First 1).Version
        Write-Status "dbatools version $installedVersion installed successfully" "Success"
    }
    catch {
        Write-Status "Failed to install dbatools: $($_.Exception.Message)" "Error"
        Write-Status "Please try installing manually: Install-Module dbatools -Force" "Info"
    }
}

# Test dbatools import
Write-Status "Testing dbatools module import..." "Info"
try {
    Import-Module dbatools -Force
    Write-Status "dbatools module imported successfully" "Success"
    
    # Get module information
    $moduleInfo = Get-Module dbatools
    Write-Status "Module Version: $($moduleInfo.Version)" "Info"
    Write-Status "Module Path: $($moduleInfo.ModuleBase)" "Info"
    Write-Status "Available Commands: $($moduleInfo.ExportedCommands.Count)" "Info"
}
catch {
    Write-Status "Failed to import dbatools module: $($_.Exception.Message)" "Error"
}

# Check for SQL Server client tools
Write-Status "Checking for SQL Server client connectivity..." "Info"
try {
    # Try to load SQL Server SMO assemblies
    Add-Type -AssemblyName "Microsoft.SqlServer.Smo" -ErrorAction SilentlyContinue
    Add-Type -AssemblyName "Microsoft.SqlServer.SmoExtended" -ErrorAction SilentlyContinue
    Write-Status "SQL Server SMO assemblies are available" "Success"
}
catch {
    Write-Status "SQL Server SMO assemblies not found - some advanced features may not work" "Warning"
    Write-Status "Consider installing SQL Server Management Studio or SQL Server client tools" "Info"
}

# Create default directories
Write-Status "Creating default directories..." "Info"
$defaultPaths = @(
    "$env:USERPROFILE\SQLMigration",
    "$env:USERPROFILE\SQLMigration\Backups",
    "$env:USERPROFILE\SQLMigration\Logs",
    "$env:USERPROFILE\SQLMigration\Scripts"
)

foreach ($path in $defaultPaths) {
    if (-not (Test-Path $path)) {
        try {
            New-Item -ItemType Directory -Path $path -Force | Out-Null
            Write-Status "Created directory: $path" "Success"
        }
        catch {
            Write-Status "Failed to create directory: $path" "Warning"
        }
    }
    else {
        Write-Status "Directory already exists: $path" "Info"
    }
}

# Test basic dbatools functionality
Write-Status "Testing basic dbatools functionality..." "Info"
try {
    # Test a simple dbatools command
    $testResult = Test-DbaConnection -SqlInstance "localhost" -ErrorAction SilentlyContinue
    if ($testResult) {
        Write-Status "Local SQL Server instance detected and accessible" "Success"
    }
    else {
        Write-Status "No local SQL Server instance detected (this is normal if SQL Server is not installed locally)" "Info"
    }
}
catch {
    Write-Status "dbatools basic functionality test completed" "Info"
}

# Display system information
Write-Status "System Information:" "Info"
Write-Status "  OS: $((Get-CimInstance Win32_OperatingSystem).Caption)" "Info"
Write-Status "  PowerShell: $($PSVersionTable.PSVersion)" "Info"
Write-Status "  .NET Framework: $($PSVersionTable.CLRVersion)" "Info"
Write-Status "  Architecture: $($env:PROCESSOR_ARCHITECTURE)" "Info"

# Display completion summary
Write-Host "`n" -NoNewline
Write-Status "Prerequisites installation completed!" "Success"
Write-Host "`nNext steps:" -ForegroundColor Yellow
Write-Host "1. Test connectivity to your SQL Server instances" -ForegroundColor White
Write-Host "2. Ensure appropriate permissions for backup/restore operations" -ForegroundColor White
Write-Host "3. Review the README.md file for usage examples" -ForegroundColor White
Write-Host "4. Run the Export-SqlServerInstance.ps1 script with your parameters" -ForegroundColor White

Write-Host "`nExample test command:" -ForegroundColor Yellow
Write-Host "Test-DbaConnection -SqlInstance 'YourServerName'" -ForegroundColor Green

Write-Host "`nFor help with the export script:" -ForegroundColor Yellow
Write-Host "Get-Help .\Export-SqlServerInstance.ps1 -Full" -ForegroundColor Green
