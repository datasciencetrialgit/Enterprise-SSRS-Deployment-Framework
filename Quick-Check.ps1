# Quick Structure Test
# Test if the deployment package structure is complete

Write-Host "SSRS Deployment Package - Structure Check" -ForegroundColor Green
Write-Host "==========================================" -ForegroundColor Green
Write-Host ""

$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# Check for required directories
$RequiredDirs = @(
    "Config",
    "Deploy",
    "Deploy\Config", 
    "Deploy\DataSources",
    "Deploy\DataSets",
    "Deploy\RDL-Files",
    "Logs"
)

Write-Host "Checking Directory Structure:" -ForegroundColor Cyan
foreach ($Dir in $RequiredDirs) {
    $DirPath = Join-Path $ScriptRoot $Dir
    if (Test-Path $DirPath) {
        Write-Host "  ✅ $Dir" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $Dir (missing)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Checking Key Files:" -ForegroundColor Cyan

$RequiredFiles = @(
    "Deploy-SSRS.ps1",
    "SSRS-Core-Functions.ps1", 
    "SSRS-Helper-Functions.ps1",
    "Config\deployment-config.json"
)

foreach ($File in $RequiredFiles) {
    $FilePath = Join-Path $ScriptRoot $File
    if (Test-Path $FilePath) {
        Write-Host "  ✅ $File" -ForegroundColor Green
    } else {
        Write-Host "  ❌ $File (missing)" -ForegroundColor Red
    }
}

Write-Host ""
Write-Host "Basic structure check complete!" -ForegroundColor Green
Write-Host "To run full validation, fix syntax errors in Validate-Setup.ps1" -ForegroundColor Yellow
