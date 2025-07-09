# ======================================================================
# SSRS Deployment Package Validation Script
# Tests the deployment package components and validates setup
# ======================================================================

<#
.SYNOPSIS
    Validates the SSRS Deployment Package setup and components.

.DESCRIPTION
    This script validates that all components of the SSRS deployment package
    are properly configured and ready for use.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ReportServerUrl = "http://localhost/ReportServer"
)

$ErrorActionPreference = "Continue"
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

Write-Host "SSRS Deployment Package Validation" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Yellow
Write-Host ""

# ======================================================================
# VALIDATION FUNCTIONS
# ======================================================================

function Test-DirectoryStructure {
    Write-Host "🔍 Testing Directory Structure..." -ForegroundColor Cyan
    
    $RequiredDirectories = @(
        "RDL-Files",
        "DataSources", 
        "DataSets",
        "SharedDataSources",
        "SharedDataSets",
        "Config",
        "Logs"
    )
    
    $AllGood = $true
    
    foreach ($Directory in $RequiredDirectories) {
        $DirectoryPath = Join-Path $ScriptRoot $Directory
        if (Test-Path $DirectoryPath) {
            Write-Host "  ✅ $Directory - EXISTS" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $Directory - MISSING" -ForegroundColor Red
            $AllGood = $false
        }
    }
    
    return $AllGood
}

function Test-ScriptFiles {
    Write-Host "🔍 Testing Script Files..." -ForegroundColor Cyan
    
    $RequiredFiles = @(
        "Deploy-SSRS.ps1",
        "SSRS-Helper-Functions.ps1",
        "README.md",
        "Examples.ps1"
    )
    
    $AllGood = $true
    
    foreach ($File in $RequiredFiles) {
        $FilePath = Join-Path $ScriptRoot $File
        if (Test-Path $FilePath) {
            Write-Host "  ✅ $File - EXISTS" -ForegroundColor Green
        } else {
            Write-Host "  ❌ $File - MISSING" -ForegroundColor Red
            $AllGood = $false
        }
    }
    
    return $AllGood
}

function Test-ConfigurationFile {
    Write-Host "🔍 Testing Configuration File..." -ForegroundColor Cyan
    
    $ConfigFile = Join-Path $ScriptRoot "Config\deployment-config.json"
    
    if (!(Test-Path $ConfigFile)) {
        Write-Host "  ❌ Configuration file missing: $ConfigFile" -ForegroundColor Red
        return $false
    }
    
    try {
        $Config = Get-Content $ConfigFile -Raw | ConvertFrom-Json
        Write-Host "  ✅ Configuration file is valid JSON" -ForegroundColor Green
        
        # Test required sections
        $RequiredSections = @("DataSources", "Deployment", "Environments")
        foreach ($Section in $RequiredSections) {
            if ($Config.$Section) {
                Write-Host "  ✅ Configuration section '$Section' - EXISTS" -ForegroundColor Green
            } else {
                Write-Host "  ⚠️  Configuration section '$Section' - MISSING" -ForegroundColor Yellow
            }
        }
        
        return $true
    }
    catch {
        Write-Host "  ❌ Configuration file has invalid JSON: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-ReportingServicesTools {
    Write-Host "🔍 Testing ReportingServicesTools..." -ForegroundColor Cyan
    
    try {
        # Check if module is installed
        $Module = Get-Module -ListAvailable -Name ReportingServicesTools -ErrorAction SilentlyContinue
        if ($Module) {
            Write-Host "  ✅ ReportingServicesTools module is installed (Version: $($Module.Version))" -ForegroundColor Green
            return $true
        }
        
        # Check if downloaded repository exists
        $RepoPath = Join-Path $ScriptRoot "..\ReportingServicesTools\ReportingServicesTools-master\ReportingServicesTools\ReportingServicesTools.psm1"
        if (Test-Path $RepoPath) {
            Write-Host "  ✅ ReportingServicesTools repository found locally" -ForegroundColor Green
            return $true
        }
        
        Write-Host "  ❌ ReportingServicesTools not found - neither installed nor in local repository" -ForegroundColor Red
        Write-Host "     To fix: Install-Module ReportingServicesTools -Force" -ForegroundColor Yellow
        Write-Host "     Or ensure the downloaded repository is in the parent directory" -ForegroundColor Yellow
        return $false
    }
    catch {
        Write-Host "  ❌ Error checking ReportingServicesTools: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
}

function Test-PowerShellVersion {
    Write-Host "🔍 Testing PowerShell Version..." -ForegroundColor Cyan
    
    $Version = $PSVersionTable.PSVersion
    Write-Host "  ℹ️  PowerShell Version: $($Version.ToString())" -ForegroundColor White
    
    if ($Version.Major -ge 5) {
        Write-Host "  ✅ PowerShell version is supported" -ForegroundColor Green
        return $true
    } else {
        Write-Host "  ❌ PowerShell version is too old (requires 5.1 or later)" -ForegroundColor Red
        return $false
    }
}

function Test-SSRSConnection {
    param([string]$ServerUrl)
    
    Write-Host "🔍 Testing SSRS Connection..." -ForegroundColor Cyan
    Write-Host "  ℹ️  Testing connection to: $ServerUrl" -ForegroundColor White
    
    try {
        # Simple web request test
        $Response = Invoke-WebRequest -Uri $ServerUrl -UseBasicParsing -TimeoutSec 10 -ErrorAction Stop
        if ($Response.StatusCode -eq 200) {
            Write-Host "  ✅ SSRS server is accessible (HTTP 200)" -ForegroundColor Green
            return $true
        } else {
            Write-Host "  ⚠️  SSRS server responded with status: $($Response.StatusCode)" -ForegroundColor Yellow
            return $false
        }
    }
    catch {
        Write-Host "  ❌ Failed to connect to SSRS server: $($_.Exception.Message)" -ForegroundColor Red
        Write-Host "     This might be normal if SSRS requires authentication or is not running" -ForegroundColor Yellow
        return $false
    }
}

function Test-SampleFiles {
    Write-Host "🔍 Testing for Sample Files..." -ForegroundColor Cyan
    
    $SamplePaths = @(
        @{ Path = "RDL-Files\*.rdl"; Type = "Report files" },
        @{ Path = "DataSources\*.rds"; Type = "Data source files" },
        @{ Path = "SharedDataSources\*.rds"; Type = "Shared data source files" },
        @{ Path = "DataSets\*.rsd"; Type = "Dataset files" },
        @{ Path = "SharedDataSets\*.rsd"; Type = "Shared dataset files" }
    )
    
    foreach ($Sample in $SamplePaths) {
        $FullPath = Join-Path $ScriptRoot $Sample.Path
        $Files = Get-ChildItem -Path $FullPath -ErrorAction SilentlyContinue
        if ($Files.Count -gt 0) {
            Write-Host "  ✅ Found $($Files.Count) $($Sample.Type)" -ForegroundColor Green
        } else {
            Write-Host "  ℹ️  No $($Sample.Type) found (this is normal for new installations)" -ForegroundColor White
        }
    }
    
    return $true
}

function Show-ValidationSummary {
    param($Results)
    
    Write-Host ""
    Write-Host "Validation Summary" -ForegroundColor Yellow
    Write-Host "==================" -ForegroundColor Yellow
    
    $TotalTests = $Results.Count
    $PassedTests = ($Results | Where-Object { $_ -eq $true }).Count
    $FailedTests = $TotalTests - $PassedTests
    
    Write-Host "Total Tests: $TotalTests" -ForegroundColor White
    Write-Host "Passed: $PassedTests" -ForegroundColor Green
    Write-Host "Failed: $FailedTests" -ForegroundColor Red
    
    if ($FailedTests -eq 0) {
        Write-Host ""
        Write-Host "🎉 All validations passed! Your SSRS Deployment Package is ready to use." -ForegroundColor Green
        Write-Host ""
        Write-Host "Next steps:" -ForegroundColor Cyan
        Write-Host "1. Place your SSRS files in the appropriate folders" -ForegroundColor White
        Write-Host "2. Update the configuration file with your environment settings" -ForegroundColor White
        Write-Host "3. Run the deployment script: .\Deploy-SSRS.ps1" -ForegroundColor White
    } else {
        Write-Host ""
        Write-Host "⚠️  Some validations failed. Please address the issues above before using the deployment package." -ForegroundColor Yellow
    }
}

# ======================================================================
# RUN VALIDATIONS
# ======================================================================

$ValidationResults = @()

$ValidationResults += Test-PowerShellVersion
$ValidationResults += Test-DirectoryStructure
$ValidationResults += Test-ScriptFiles
$ValidationResults += Test-ConfigurationFile
$ValidationResults += Test-ReportingServicesTools
$ValidationResults += Test-SSRSConnection -ServerUrl $ReportServerUrl
$ValidationResults += Test-SampleFiles

Show-ValidationSummary -Results $ValidationResults

Write-Host ""
Write-Host "For usage examples, run: .\Examples.ps1" -ForegroundColor Cyan
Write-Host "For full documentation, see: README.md" -ForegroundColor Cyan
