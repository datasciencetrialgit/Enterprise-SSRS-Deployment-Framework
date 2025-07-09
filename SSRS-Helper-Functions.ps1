# ======================================================================
# SSRS Component Deployment Helper
# Individual deployment functions for specific SSRS components
# ======================================================================

<#
.SYNOPSIS
    Helper functions for deploying individual SSRS components.

.DESCRIPTION
    This script provides individual deployment functions that can be called
    independently for specific components like data sources, datasets, or reports.
#>

# Import the main deployment functions
. "$PSScriptRoot\Deploy-SSRS.ps1"

# Import SSRS Core Functions
. "$PSScriptRoot\SSRS-Core-Functions.ps1"

# ======================================================================
# INDIVIDUAL DEPLOYMENT FUNCTIONS
# ======================================================================

function Deploy-SingleReport {
    <#
    .SYNOPSIS
        Deploy a single RDL report file to SSRS.
    
    .PARAMETER ReportPath
        Path to the RDL file to deploy.
    
    .PARAMETER ReportServerUrl
        SSRS Report Server URL.
    
    .PARAMETER TargetFolder
        Target folder on the report server.
    
    .PARAMETER Overwrite
        Overwrite existing report if it exists.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportPath,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetFolder,
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Host "Deploying single report: $ReportPath" -ForegroundColor Green
    
    try {
        # Load SSRS Core Functions
        if (!(Import-ReportingServicesTools)) {
            throw "Failed to load SSRS Core Functions"
        }
        
        # Connect to SSRS
        if ($Credential) {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl -Credential $Credential
        } else {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl
        }
        
        # Create target folder if it doesn't exist
        New-SSRSFolder -FolderPath $TargetFolder
        
        # Deploy the report
        Write-RsCatalogItem -Path $ReportPath -RsFolder $TargetFolder -Overwrite:$Overwrite
        
        Write-Host "Successfully deployed report: $(Split-Path $ReportPath -Leaf)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to deploy report: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Deploy-SingleDataSource {
    <#
    .SYNOPSIS
        Deploy a single data source to SSRS.
    
    .PARAMETER DataSourceName
        Name of the data source.
    
    .PARAMETER ConnectionString
        Connection string for the data source.
    
    .PARAMETER ReportServerUrl
        SSRS Report Server URL.
    
    .PARAMETER TargetFolder
        Target folder on the report server.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataSourceName,
        
        [Parameter(Mandatory = $true)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetFolder = "/Data Sources",
        
        [Parameter(Mandatory = $false)]
        [string]$Extension = "SQL",
        
        [Parameter(Mandatory = $false)]
        [string]$CredentialRetrieval = "Integrated",
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$DatasourceCredentials
    )
    
    Write-Host "Deploying data source: $DataSourceName" -ForegroundColor Green
    
    try {
        # Load SSRS Core Functions
        if (!(Import-ReportingServicesTools)) {
            throw "Failed to load SSRS Core Functions"
        }
        
        # Connect to SSRS
        if ($Credential) {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl -Credential $Credential
        } else {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl
        }
        
        # Create target folder if it doesn't exist
        New-SSRSFolder -FolderPath $TargetFolder
        
        # Create the data source
        $DataSourceParams = @{
            RsFolder = $TargetFolder
            Name = $DataSourceName
            Extension = $Extension
            ConnectionString = $ConnectionString
            CredentialRetrieval = $CredentialRetrieval
            Overwrite = $Overwrite
        }
        
        if ($DatasourceCredentials) {
            $DataSourceParams.DatasourceCredentials = $DatasourceCredentials
        }
        
        New-RsDataSource @DataSourceParams
        
        Write-Host "Successfully deployed data source: $DataSourceName" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to deploy data source: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Deploy-SingleDataSet {
    <#
    .SYNOPSIS
        Deploy a single shared dataset file to SSRS.
    
    .PARAMETER DataSetPath
        Path to the RSD file to deploy.
    
    .PARAMETER ReportServerUrl
        SSRS Report Server URL.
    
    .PARAMETER TargetFolder
        Target folder on the report server.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$DataSetPath,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetFolder = "/DataSets",
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Host "Deploying dataset: $DataSetPath" -ForegroundColor Green
    
    try {
        # Load SSRS Core Functions
        if (!(Import-ReportingServicesTools)) {
            throw "Failed to load SSRS Core Functions"
        }
        
        # Connect to SSRS
        if ($Credential) {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl -Credential $Credential
        } else {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl
        }
        
        # Create target folder if it doesn't exist
        New-SSRSFolder -FolderPath $TargetFolder
        
        # Deploy the dataset
        Write-RsCatalogItem -Path $DataSetPath -RsFolder $TargetFolder -Overwrite:$Overwrite
        
        Write-Host "Successfully deployed dataset: $(Split-Path $DataSetPath -Leaf)" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to deploy dataset: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Deploy-FromFolder {
    <#
    .SYNOPSIS
        Deploy all files from a specific folder.
    
    .PARAMETER SourceFolder
        Source folder containing files to deploy.
    
    .PARAMETER FileExtension
        File extension to filter (e.g., "*.rdl", "*.rds", "*.rsd").
    
    .PARAMETER ReportServerUrl
        SSRS Report Server URL.
    
    .PARAMETER TargetFolder
        Target folder on the report server.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$SourceFolder,
        
        [Parameter(Mandatory = $true)]
        [string]$FileExtension,
        
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUrl,
        
        [Parameter(Mandatory = $true)]
        [string]$TargetFolder,
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Host "Deploying files from folder: $SourceFolder" -ForegroundColor Green
    Write-Host "File pattern: $FileExtension" -ForegroundColor Cyan
    
    try {
        # Load SSRS Core Functions
        if (!(Import-ReportingServicesTools)) {
            throw "Failed to load SSRS Core Functions"
        }
        
        # Connect to SSRS
        if ($Credential) {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl -Credential $Credential
        } else {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl
        }
        
        # Get files to deploy
        $Files = Get-ChildItem -Path $SourceFolder -Filter $FileExtension -Recurse
        
        if ($Files.Count -eq 0) {
            Write-Host "No files found matching pattern: $FileExtension" -ForegroundColor Yellow
            return
        }
        
        Write-Host "Found $($Files.Count) files to deploy" -ForegroundColor Cyan
        
        # Create target folder if it doesn't exist
        New-SSRSFolder -FolderPath $TargetFolder
        
        # Deploy each file
        foreach ($File in $Files) {
            try {
                Write-Host "  Deploying: $($File.Name)" -ForegroundColor White
                Write-RsCatalogItem -Path $File.FullName -RsFolder $TargetFolder -Overwrite:$Overwrite
                Write-Host "    Success!" -ForegroundColor Green
            }
            catch {
                Write-Host "    Failed: $($_.Exception.Message)" -ForegroundColor Red
            }
        }
        
        Write-Host "Deployment from folder completed" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to deploy from folder: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

function Get-SSRSInventory {
    <#
    .SYNOPSIS
        Get inventory of deployed items on SSRS server.
    
    .PARAMETER ReportServerUrl
        SSRS Report Server URL.
    
    .PARAMETER RootFolder
        Root folder to scan (default is "/").
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$RootFolder = "/",
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Host "Getting SSRS inventory from: $ReportServerUrl" -ForegroundColor Green
    
    try {
        # Load SSRS Core Functions
        if (!(Import-ReportingServicesTools)) {
            throw "Failed to load SSRS Core Functions"
        }
        
        # Connect to SSRS
        if ($Credential) {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl -Credential $Credential
        } else {
            Connect-RsReportServer -ReportServerUri $ReportServerUrl
        }
        
        # Get all items
        $Items = Get-RsFolderContent -RsFolder $RootFolder -Recurse
        
        Write-Host "`nSSRS Inventory Report" -ForegroundColor Yellow
        Write-Host "=====================" -ForegroundColor Yellow
        Write-Host "Server: $ReportServerUrl" -ForegroundColor Cyan
        Write-Host "Scanned Folder: $RootFolder" -ForegroundColor Cyan
        Write-Host "Total Items: $($Items.Count)" -ForegroundColor Cyan
        Write-Host ""
        
        # Group by type
        $ItemsByType = $Items | Group-Object TypeName | Sort-Object Name
        
        foreach ($ItemType in $ItemsByType) {
            Write-Host "$($ItemType.Name): $($ItemType.Count) items" -ForegroundColor White
        }
        
        Write-Host "`nDetailed List:" -ForegroundColor Yellow
        Write-Host "--------------" -ForegroundColor Yellow
        
        $Items | Sort-Object Path | ForEach-Object {
            Write-Host "$($_.TypeName.PadRight(15)) $($_.Path)" -ForegroundColor Gray
        }
        
        return $Items
    }
    catch {
        Write-Host "Failed to get SSRS inventory: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ======================================================================
# HELPER FUNCTIONS READY FOR USE
# ======================================================================

# Functions are available when this script is dot-sourced:
# - Deploy-SingleReport
# - Deploy-SingleDataSource  
# - Deploy-SingleDataSet
# - Deploy-FromFolder
# - Get-SSRSInventory

Write-Host "SSRS Helper Functions loaded successfully!" -ForegroundColor Green
Write-Host "Available functions:" -ForegroundColor Cyan
Write-Host "  - Deploy-SingleReport" -ForegroundColor White
Write-Host "  - Deploy-SingleDataSource" -ForegroundColor White
Write-Host "  - Deploy-SingleDataSet" -ForegroundColor White
Write-Host "  - Deploy-FromFolder" -ForegroundColor White
Write-Host "  - Get-SSRSInventory" -ForegroundColor White
