# ======================================================================
# SSRS Deployment Package - Example Usage Script
# This script demonstrates various ways to use the SSRS deployment package
# ======================================================================

<#
.SYNOPSIS
    Example script showing how to use the SSRS Deployment Package.

.DESCRIPTION
    This script provides practical examples of how to use the SSRS deployment
    package for different scenarios and use cases.
#>

# Set script location
$ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path

# ======================================================================
# EXAMPLE 1: BASIC DEPLOYMENT
# ======================================================================

Write-Host "Example 1: Basic Deployment" -ForegroundColor Yellow
Write-Host "===========================" -ForegroundColor Yellow

# Basic deployment to DATA SSRS instance
$BasicParams = @{
    ReportServerUrl = "http://data/ReportServer"
    TargetFolder = "/Example Reports"
    Environment = "Dev"
}

Write-Host "Command: .\Deploy-SSRS.ps1 -ReportServerUrl '$($BasicParams.ReportServerUrl)' -TargetFolder '$($BasicParams.TargetFolder)' -Environment '$($BasicParams.Environment)'" -ForegroundColor Green
Write-Host ""

# Uncomment to execute:
# & "$ScriptRoot\Deploy-SSRS.ps1" @BasicParams

# ======================================================================
# EXAMPLE 2: WHATIF DEPLOYMENT (TEST MODE)
# ======================================================================

Write-Host "Example 2: WhatIf Deployment (Test Mode)" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

$WhatIfParams = @{
    ReportServerUrl = "http://data/ReportServer"
    TargetFolder = "/Test Reports"
    Environment = "Dev"
    WhatIf = $true
}

Write-Host "Command: .\Deploy-SSRS.ps1 -ReportServerUrl '$($WhatIfParams.ReportServerUrl)' -TargetFolder '$($WhatIfParams.TargetFolder)' -Environment '$($WhatIfParams.Environment)' -WhatIf" -ForegroundColor Green
Write-Host "This will show what would be deployed without actually deploying anything." -ForegroundColor Cyan
Write-Host ""

# Uncomment to execute:
# & "$ScriptRoot\Deploy-SSRS.ps1" @WhatIfParams

# ======================================================================
# EXAMPLE 3: DEPLOYMENT WITH CREDENTIALS
# ======================================================================

Write-Host "Example 3: Deployment with Credentials" -ForegroundColor Yellow
Write-Host "======================================" -ForegroundColor Yellow

Write-Host "For environments requiring authentication:" -ForegroundColor Cyan
Write-Host "# Secure method using variables:" -ForegroundColor Green
Write-Host "`$User = 'datasciencetrial@outlook.com'" -ForegroundColor Green
Write-Host "`$Pwd = 'ITrustU001!'" -ForegroundColor Green
Write-Host ".\Deploy-SSRS.ps1 -Environment 'Prod' -User `$User -Pwd `$Pwd" -ForegroundColor Green
Write-Host ""
Write-Host "# Direct method (password visible in history):" -ForegroundColor Yellow
Write-Host ".\Deploy-SSRS.ps1 -Environment 'Prod' -User 'datasciencetrial@outlook.com' -Pwd 'ITrustU001!'" -ForegroundColor Yellow
Write-Host ""
Write-Host "Or use credential object:" -ForegroundColor Cyan
Write-Host "`$Credential = Get-Credential" -ForegroundColor Green
Write-Host ".\Deploy-SSRS.ps1 -ReportServerUrl 'http://server/ReportServer' -TargetFolder '/Reports' -Environment 'Prod' -Credential `$Credential" -ForegroundColor Green
Write-Host ""
Write-Host "Or prompt for credentials at runtime:" -ForegroundColor Cyan
Write-Host ".\Deploy-SSRS.ps1 -ReportServerUrl 'http://server/ReportServer' -Environment 'Prod' -PromptForCredentials" -ForegroundColor Green
Write-Host ""

# ======================================================================
# EXAMPLE 4: INDIVIDUAL COMPONENT DEPLOYMENT
# ======================================================================

Write-Host "Example 4: Individual Component Deployment" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

Write-Host "Import helper functions first:" -ForegroundColor Cyan
Write-Host ". .\SSRS-Helper-Functions.ps1" -ForegroundColor Green
Write-Host ""

# Import the helper functions
. "$ScriptRoot\SSRS-Helper-Functions.ps1"

Write-Host "Deploy a single report:" -ForegroundColor Cyan
Write-Host "Deploy-SingleReport -ReportPath 'RDL-Files\MyReport.rdl' -ReportServerUrl 'http://localhost/ReportServer' -TargetFolder '/Reports' -Overwrite" -ForegroundColor Green
Write-Host ""

Write-Host "Deploy a single data source:" -ForegroundColor Cyan
Write-Host "Deploy-SingleDataSource -DataSourceName 'AdventureWorks' -ConnectionString 'Data Source=localhost;Initial Catalog=AdventureWorks2019;Integrated Security=True' -ReportServerUrl 'http://localhost/ReportServer'" -ForegroundColor Green
Write-Host ""

Write-Host "Deploy all RDL files from a folder:" -ForegroundColor Cyan
Write-Host "Deploy-FromFolder -SourceFolder 'RDL-Files' -FileExtension '*.rdl' -ReportServerUrl 'http://localhost/ReportServer' -TargetFolder '/Reports' -Overwrite" -ForegroundColor Green
Write-Host ""

# ======================================================================
# EXAMPLE 5: ENVIRONMENT-SPECIFIC DEPLOYMENTS
# ======================================================================

Write-Host "Example 5: Environment-Specific Deployments" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

Write-Host "Development Environment:" -ForegroundColor Cyan
$DevParams = @{
    ReportServerUrl = "http://dev-server/ReportServer"
    TargetFolder = "/Dev-Reports"
    Environment = "Dev"
}
Write-Host ".\Deploy-SSRS.ps1 -ReportServerUrl '$($DevParams.ReportServerUrl)' -TargetFolder '$($DevParams.TargetFolder)' -Environment '$($DevParams.Environment)'" -ForegroundColor Green
Write-Host ""

Write-Host "Test Environment:" -ForegroundColor Cyan
$TestParams = @{
    ReportServerUrl = "http://test-server/ReportServer"
    TargetFolder = "/Test-Reports"
    Environment = "Test"
}
Write-Host ".\Deploy-SSRS.ps1 -ReportServerUrl '$($TestParams.ReportServerUrl)' -TargetFolder '$($TestParams.TargetFolder)' -Environment '$($TestParams.Environment)'" -ForegroundColor Green
Write-Host ""

Write-Host "Production Environment:" -ForegroundColor Cyan
$ProdParams = @{
    ReportServerUrl = "https://prod-server/ReportServer"
    TargetFolder = "/Prod-Reports"
    Environment = "Prod"
}
Write-Host ".\Deploy-SSRS.ps1 -ReportServerUrl '$($ProdParams.ReportServerUrl)' -TargetFolder '$($ProdParams.TargetFolder)' -Environment '$($ProdParams.Environment)' -Credential (Get-Credential)" -ForegroundColor Green
Write-Host ""

# ======================================================================
# EXAMPLE 6: SSRS INVENTORY AND VALIDATION
# ======================================================================

Write-Host "Example 6: SSRS Inventory and Validation" -ForegroundColor Yellow
Write-Host "========================================" -ForegroundColor Yellow

Write-Host "Get complete SSRS server inventory:" -ForegroundColor Cyan
Write-Host "Get-SSRSInventory -ReportServerUrl 'http://localhost/ReportServer' -RootFolder '/'" -ForegroundColor Green
Write-Host ""

Write-Host "Get inventory for specific folder:" -ForegroundColor Cyan
Write-Host "Get-SSRSInventory -ReportServerUrl 'http://localhost/ReportServer' -RootFolder '/Reports'" -ForegroundColor Green
Write-Host ""

# Example execution (uncomment to run):
# Get-SSRSInventory -ReportServerUrl "http://localhost/ReportServer" -RootFolder "/"

# ======================================================================
# EXAMPLE 7: CREATING SAMPLE FILES
# ======================================================================

Write-Host "Example 7: Creating Sample Files for Testing" -ForegroundColor Yellow
Write-Host "===========================================" -ForegroundColor Yellow

function Create-SampleFiles {
    Write-Host "Creating sample files for testing..." -ForegroundColor Cyan
    
    # Create sample RDL content
    $SampleRDL = @'
<?xml version="1.0" encoding="utf-8"?>
<Report xmlns="http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition" xmlns:rd="http://schemas.microsoft.com/SQLServer/reporting/reportdesigner">
  <AutoRefresh>0</AutoRefresh>
  <ReportParameters>
    <ReportParameter Name="ReportTitle">
      <DataType>String</DataType>
      <DefaultValue>
        <Values>
          <Value>Sample Report</Value>
        </Values>
      </DefaultValue>
      <Prompt>Report Title</Prompt>
    </ReportParameter>
  </ReportParameters>
  <Body>
    <ReportItems>
      <Textbox Name="Title">
        <CanGrow>true</CanGrow>
        <KeepTogether>true</KeepTogether>
        <Paragraphs>
          <Paragraph>
            <TextRuns>
              <TextRun>
                <Value>=Parameters!ReportTitle.Value</Value>
                <Style>
                  <FontSize>18pt</FontSize>
                  <FontWeight>Bold</FontWeight>
                </Style>
              </TextRun>
            </TextRuns>
          </Paragraph>
        </Paragraphs>
        <rd:DefaultName>Title</rd:DefaultName>
        <Top>0.25in</Top>
        <Left>0.25in</Left>
        <Height>0.5in</Height>
        <Width>7in</Width>
      </Textbox>
    </ReportItems>
    <Height>2in</Height>
  </Body>
  <Width>8in</Width>
  <Page>
    <LeftMargin>1in</LeftMargin>
    <RightMargin>1in</RightMargin>
    <TopMargin>1in</TopMargin>
    <BottomMargin>1in</BottomMargin>
  </Page>
</Report>
'@

    # Create sample RDS content
    $SampleRDS = @'
<?xml version="1.0" encoding="utf-8"?>
<RptDataSource xmlns:xsi="http://www.w3.org/2001/XMLSchema-instance" xmlns:xsd="http://www.w3.org/2001/XMLSchema" Name="SampleDataSource">
  <ConnectionProperties>
    <Extension>SQL</Extension>
    <ConnectString>Data Source=localhost;Initial Catalog=AdventureWorks2019</ConnectString>
    <IntegratedSecurity>true</IntegratedSecurity>
  </ConnectionProperties>
  <DataSourceID>12345678-1234-1234-1234-123456789012</DataSourceID>
</RptDataSource>
'@

    # Create directories if they don't exist
    $Directories = @("RDL-Files", "DataSources")
    foreach ($Dir in $Directories) {
        $DirPath = Join-Path $ScriptRoot $Dir
        if (!(Test-Path $DirPath)) {
            New-Item -ItemType Directory -Path $DirPath -Force | Out-Null
            Write-Host "Created directory: $Dir" -ForegroundColor Green
        }
    }
    
    # Create sample files
    $SampleRDL | Out-File -FilePath (Join-Path $ScriptRoot "RDL-Files\SampleReport.rdl") -Encoding UTF8
    $SampleRDS | Out-File -FilePath (Join-Path $ScriptRoot "DataSources\SampleDataSource.rds") -Encoding UTF8
    
    Write-Host "Sample files created:" -ForegroundColor Green
    Write-Host "  - RDL-Files\SampleReport.rdl" -ForegroundColor White
    Write-Host "  - DataSources\SampleDataSource.rds" -ForegroundColor White
}

Write-Host "To create sample files for testing, run:" -ForegroundColor Cyan
Write-Host "Create-SampleFiles" -ForegroundColor Green
Write-Host ""

# ======================================================================
# EXAMPLE 8: BATCH DEPLOYMENT SCRIPT
# ======================================================================

Write-Host "Example 8: Batch Deployment Script" -ForegroundColor Yellow
Write-Host "===================================" -ForegroundColor Yellow

function Start-BatchDeployment {
    param(
        [string]$ReportServerUrl = "http://localhost/ReportServer",
        [string]$BaseFolder = "/Deployed Reports"
    )
    
    Write-Host "Starting batch deployment to: $ReportServerUrl" -ForegroundColor Green
    
    # Deploy to different folders based on content type
    $Deployments = @(
        @{ Source = "RDL-Files"; Target = "$BaseFolder/Reports"; Type = "Reports" },
        @{ Source = "DataSources"; Target = "$BaseFolder/Data Sources"; Type = "Data Sources" },
        @{ Source = "DataSets"; Target = "$BaseFolder/Data Sets"; Type = "Data Sets" }
    )
    
    foreach ($Deployment in $Deployments) {
        $SourcePath = Join-Path $ScriptRoot $Deployment.Source
        if (Test-Path $SourcePath) {
            Write-Host "Deploying $($Deployment.Type)..." -ForegroundColor Cyan
            Write-Host "  Source: $($Deployment.Source)" -ForegroundColor White
            Write-Host "  Target: $($Deployment.Target)" -ForegroundColor White
            
            # Here you would call the deployment functions
            # This is just an example of the structure
        } else {
            Write-Host "Skipping $($Deployment.Type) - source folder not found" -ForegroundColor Yellow
        }
    }
}

Write-Host "To run batch deployment:" -ForegroundColor Cyan
Write-Host "Start-BatchDeployment -ReportServerUrl 'http://localhost/ReportServer' -BaseFolder '/My Reports'" -ForegroundColor Green
Write-Host ""

# ======================================================================
# CONCLUSION
# ======================================================================

Write-Host "Conclusion" -ForegroundColor Yellow
Write-Host "==========" -ForegroundColor Yellow
Write-Host "This example script demonstrates various ways to use the SSRS Deployment Package." -ForegroundColor White
Write-Host "Uncomment the relevant lines to execute the deployments." -ForegroundColor White
Write-Host ""
Write-Host "For more information, see the README.md file." -ForegroundColor Cyan
Write-Host "Happy deploying! 🚀" -ForegroundColor Green
