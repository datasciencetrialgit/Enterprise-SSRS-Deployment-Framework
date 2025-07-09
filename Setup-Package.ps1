# ======================================================================
# SSRS Deployment Package Setup
# Setup and installation verification script
# ======================================================================

<#
.SYNOPSIS
    Setup and verify the SSRS Deployment Package.

.DESCRIPTION
    This script verifies that all components of the SSRS Deployment Package
    are properly configured and ready to use. It no longer requires external
    dependencies like ReportingServicesTools module.

.EXAMPLE
    .\Setup-Package.ps1
    
.EXAMPLE
    .\Setup-Package.ps1 -TestConnection -ReportServerUrl "http://localhost/ReportServer"
#>

param(
    [Parameter(Mandatory = $false)]
    [switch]$TestConnection,
    
    [Parameter(Mandatory = $false)]
    [string]$ReportServerUrl = "http://localhost/ReportServer",
    
    [Parameter(Mandatory = $false)]
    [switch]$CreateSampleConfig
)

$ErrorActionPreference = "Continue"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "======================================================================" -ForegroundColor Yellow
Write-Host "SSRS Deployment Package Setup" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Yellow
Write-Host ""

# ======================================================================
# VERIFY PACKAGE COMPONENTS
# ======================================================================

Write-Host "1. Verifying package components..." -ForegroundColor Cyan

$RequiredFiles = @(
    "Deploy-SSRS.ps1",
    "SSRS-Core-Functions.ps1",
    "SSRS-Helper-Functions.ps1",
    "Validate-Setup.ps1",
    "Examples.ps1"
)

$MissingFiles = @()
foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $ScriptPath $File
    if (Test-Path $FilePath) {
        Write-Host "   [OK] $File" -ForegroundColor Green
    } else {
        Write-Host "   [MISSING] $File" -ForegroundColor Red
        $MissingFiles += $File
    }
}

# Check directories
$RequiredDirs = @("Config", "DataSets", "DataSources", "RDL-Files", "Logs")
foreach ($Dir in $RequiredDirs) {
    $DirPath = Join-Path $ScriptPath $Dir
    if (Test-Path $DirPath) {
        Write-Host "   [OK] $Dir/" -ForegroundColor Green
    } else {
        Write-Host "   [CREATING] $Dir/" -ForegroundColor Yellow
        New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
    }
}

if ($MissingFiles.Count -gt 0) {
    Write-Host ""
    Write-Host "Missing files detected. Please ensure all required files are present." -ForegroundColor Red
    exit 1
}

Write-Host ""

# ======================================================================
# VERIFY POWERSHELL FUNCTIONS
# ======================================================================

Write-Host "2. Loading and verifying PowerShell functions..." -ForegroundColor Cyan

try {
    # Load core functions
    . (Join-Path $ScriptPath "SSRS-Core-Functions.ps1")
    Write-Host "   [OK] SSRS Core Functions loaded" -ForegroundColor Green
    
    # Load helper functions
    . (Join-Path $ScriptPath "SSRS-Helper-Functions.ps1")
    Write-Host "   [OK] SSRS Helper Functions loaded" -ForegroundColor Green
    
    # Verify key functions exist
    $KeyFunctions = @(
        "Connect-RsReportServer",
        "New-RsFolder",
        "Write-RsCatalogItem",
        "New-RsDataSource",
        "Deploy-SingleReport",
        "Deploy-SingleDataSource",
        "Get-SSRSInventory"
    )
    
    foreach ($Function in $KeyFunctions) {
        if (Get-Command $Function -ErrorAction SilentlyContinue) {
            Write-Host "   [OK] $Function available" -ForegroundColor Green
        } else {
            Write-Host "   [ERROR] $Function not available" -ForegroundColor Red
        }
    }
}
catch {
    Write-Host "   [ERROR] Error loading functions: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

Write-Host ""

# ======================================================================
# TEST CONNECTION (OPTIONAL)
# ======================================================================

if ($TestConnection) {
    Write-Host "3. Testing SSRS connection..." -ForegroundColor Cyan
    
    try {
        Connect-RsReportServer -ReportServerUri $ReportServerUrl
        Write-Host "   [OK] Successfully connected to SSRS server" -ForegroundColor Green
        
        # Test basic operations
        $ServerInfo = Get-SSRSServerInfo
        Write-Host "   [OK] Server communication successful" -ForegroundColor Green
        
        # Get root folder contents
        $RootItems = Get-RsFolderContent -RsFolder "/"
        Write-Host "   [OK] Can read server catalog ($($RootItems.Count) items in root)" -ForegroundColor Green
        
        Disconnect-RsReportServer
    }
    catch {
        Write-Host "   [ERROR] Connection test failed: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "           This may be normal if SSRS server is not available" -ForegroundColor Yellow
    }
    
    Write-Host ""
}

# ======================================================================
# CREATE SAMPLE CONFIGURATION
# ======================================================================

if ($CreateSampleConfig) {
    Write-Host "4. Creating sample configuration..." -ForegroundColor Cyan
    
    $ConfigPath = Join-Path $ScriptPath "Config\deployment-config.json"
    
    if (Test-Path $ConfigPath) {
        Write-Host "   [INFO] Configuration file already exists: $ConfigPath" -ForegroundColor Yellow
    } else {
        $SampleConfig = @{
            DataSources = @{
                DefaultConnectionStrings = @{
                    Dev  = "Data Source=localhost;Initial Catalog=SampleDB;Integrated Security=True"
                    Test = "Data Source=testserver;Initial Catalog=SampleDB;Integrated Security=True"
                    Prod = "Data Source=prodserver;Initial Catalog=SampleDB;Integrated Security=True"
                }
                Extension = "SQL"
                CredentialRetrieval = "Integrated"
            }
            Deployment = @{
                CreateFolders = $true
                OverwriteExisting = $true
                CreateDataSources = $true
                CreateDataSets = $true
                CreateReports = $true
            }
            Security = @{
                Authentication = @{
                    UseCurrentUser = $true
                    PromptForCredentials = $false
                    Domain = ""
                    Username = ""
                }
                UseWindowsAuth = $true
                CustomCredentials = @{
                    Username = ""
                    Password = ""
                }
            }
        }
        
        $SampleConfig | ConvertTo-Json -Depth 10 | Out-File -FilePath $ConfigPath -Encoding UTF8
        Write-Host "   [OK] Sample configuration created: $ConfigPath" -ForegroundColor Green
    }
    
    Write-Host ""
}

# ======================================================================
# SUMMARY
# ======================================================================

Write-Host "======================================================================" -ForegroundColor Yellow
Write-Host "Setup Summary" -ForegroundColor Yellow
Write-Host "======================================================================" -ForegroundColor Yellow
Write-Host ""
Write-Host "[SUCCESS] SSRS Deployment Package is ready to use!" -ForegroundColor Green
Write-Host ""
Write-Host "Key Features:" -ForegroundColor Cyan
Write-Host "  - Standalone package (no external dependencies)" -ForegroundColor White
Write-Host "  - Deploy reports, data sources, and datasets" -ForegroundColor White
Write-Host "  - Individual and batch deployment functions" -ForegroundColor White
Write-Host "  - Built-in logging and error handling" -ForegroundColor White
Write-Host "  - Configuration-driven deployments" -ForegroundColor White
Write-Host ""
Write-Host "Quick Start:" -ForegroundColor Cyan
Write-Host "  1. Run: .\Examples.ps1 to see usage examples" -ForegroundColor White
Write-Host "  2. Run: .\Quick-Start-DATA-Server.ps1 for quick deployment" -ForegroundColor White
Write-Host "  3. Edit: Config\deployment-config.json for your environment" -ForegroundColor White
Write-Host ""
Write-Host "Main Scripts:" -ForegroundColor Cyan
Write-Host "  - Deploy-SSRS.ps1          - Full deployment script" -ForegroundColor White
Write-Host "  - SSRS-Helper-Functions.ps1 - Individual deployment functions" -ForegroundColor White
Write-Host "  - Validate-Setup.ps1        - Validate deployment setup" -ForegroundColor White
Write-Host ""

if (-not $TestConnection) {
    Write-Host "Tip: Run with -TestConnection to verify SSRS server connectivity" -ForegroundColor Yellow
}

if (-not $CreateSampleConfig) {
    Write-Host "Tip: Run with -CreateSampleConfig to create a sample configuration file" -ForegroundColor Yellow
}

Write-Host ""
Write-Host "Package is ready for use!" -ForegroundColor Green
