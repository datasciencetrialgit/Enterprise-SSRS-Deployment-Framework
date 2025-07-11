# Test GitHub Actions Authentication Parameters
# This script demonstrates how to use the User and Password parameters
# for automated CI/CD deployments

<#
.SYNOPSIS
    Test script to validate SSRS deployment with username/password authentication

.DESCRIPTION
    This script shows how to use the Deploy-SSRS.ps1 script with username and password
    parameters, which is ideal for GitHub Actions, Azure DevOps, and other CI/CD platforms.

.EXAMPLE
    .\Test-CI-CD-Authentication.ps1
#>

param(
    [Parameter(Mandatory = $true)]
    [ValidateSet("Dev", "Test", "Prod")]
    [string]$Environment,
    
    [Parameter(Mandatory = $true)]
    [string]$Username,
    
    [Parameter(Mandatory = $true)]
    [string]$Password
)

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "SSRS Deployment Package - CI/CD Authentication Test" -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host ""

Write-Host "Testing authentication parameters for CI/CD integration..." -ForegroundColor Yellow
Write-Host "Environment: $Environment" -ForegroundColor Green
Write-Host "Username: $Username" -ForegroundColor Green
Write-Host "Password: $('*' * $Password.Length)" -ForegroundColor Green
Write-Host ""
Write-Host "ReportServerUrl and TargetFolder will be read from Config/deployment-config.json" -ForegroundColor Cyan
Write-Host ""

try {
    Write-Host "Step 1: Testing connection with WhatIf mode..." -ForegroundColor Yellow
    
    # Test deployment with WhatIf to validate authentication
    .\Deploy-SSRS.ps1 `
        -Environment $Environment `
        -User $Username `
        -Password $Password `
        -WhatIf
    
    Write-Host ""
    Write-Host "✅ Authentication test completed successfully!" -ForegroundColor Green
    Write-Host ""
    Write-Host "You can now use these parameters in your CI/CD pipeline:" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "GitHub Actions Example:" -ForegroundColor White
    Write-Host ".\Deploy-SSRS.ps1 -Environment `"Prod`" -User `"`${{ secrets.SSRS_USERNAME }}`" -Password `"`${{ secrets.SSRS_PASSWORD }}`"" -ForegroundColor Gray
    Write-Host ""
    Write-Host "Azure DevOps Example:" -ForegroundColor White
    Write-Host ".\Deploy-SSRS.ps1 -Environment `"`$(Environment)`" -User `"`$(SSRS_USERNAME)`" -Password `"`$(SSRS_PASSWORD)`"" -ForegroundColor Gray
    Write-Host ""
    
}
catch {
    Write-Host ""
    Write-Host "❌ Authentication test failed!" -ForegroundColor Red
    Write-Host "Error: $($_.Exception.Message)" -ForegroundColor Red
    Write-Host ""
    Write-Host "Common issues to check:" -ForegroundColor Yellow
    Write-Host "1. Verify the SSRS server URL is correct and accessible" -ForegroundColor White
    Write-Host "2. Ensure the username and password are correct" -ForegroundColor White
    Write-Host "3. Check that the user account has SSRS permissions" -ForegroundColor White
    Write-Host "4. Verify network connectivity to the SSRS server" -ForegroundColor White
    Write-Host ""
    exit 1
}

Write-Host "======================================================================" -ForegroundColor Cyan
Write-Host "Test completed! Check the logs in the Logs/ directory for details." -ForegroundColor Cyan
Write-Host "======================================================================" -ForegroundColor Cyan
