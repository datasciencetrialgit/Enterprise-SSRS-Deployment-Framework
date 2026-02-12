# ======================================================================
# Enterprise-SSRS-Deployment-Framework
# PowerShell Script for deploying SSRS Reports, DataSources, and DataSets
# Based on Microsoft ReportingServicesTools
# ======================================================================

<#
.SYNOPSIS
    Comprehensive Enterprise-SSRS-Deployment-Framework for deploying reports, data sources, and datasets.

.DESCRIPTION
    This script provides a complete deployment solution for SQL Server Reporting Services (SSRS).
    It supports deployment of:
    - RDL Report files
    - Data Sources
    - Data Sets
    
    The script uses standalone SSRS core functions (no external dependencies required).
    Configuration values are read from deployment-config.json by default.

.PARAMETER ReportServerUrl
    The URL of the SSRS Report Server (e.g., http://localhost/ReportServer)
    If not provided, will be read from configuration file based on Environment.

.PARAMETER TargetFolder
    The target folder on the report server where items will be deployed
    If not provided, will use the Reports folder from configuration.

.PARAMETER Environment
    Deployment environment (Dev, Test, Prod) - determines which config values to use

.PARAMETER ConfigFile
    Path to the deployment configuration file

.PARAMETER Credential
    PSCredential object for SSRS authentication

.PARAMETER User
    Username for SSRS authentication (use with Password parameter for CI/CD scenarios)

.PARAMETER Password
    Password for SSRS authentication (use with User parameter for CI/CD scenarios)

.PARAMETER PromptForCredentials
    Switch to prompt for credentials interactively

.PARAMETER Force
    Force deployment ignoring warnings

.PARAMETER WhatIf
    Test deployment without making actual changes

.EXAMPLE
    .\Deploy-SSRS.ps1 -Environment "Dev"
    Deploys using configuration values for Dev environment with current user authentication

.EXAMPLE
    .\Deploy-SSRS.ps1 -Environment "Prod" -User "domain\username" -Password "password"
    Deploys to Prod environment with username/password (ideal for CI/CD and GitHub Actions)

.EXAMPLE
    .\Deploy-SSRS.ps1 -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/MyReports" -Environment "Dev"
    Deploys with explicit parameters, overriding configuration values

.EXAMPLE
    .\Deploy-SSRS.ps1 -Environment "Dev" -User "domain\username" -Password "password" -WhatIf
    Test deployment without making changes

.NOTES
    Author: SSRS Deployment Tool
    Date: July 9, 2025
    Requires: PowerShell 5.1+, SSRS 2016+
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$ReportServerUrl,
    
    [Parameter(Mandatory = $false)]
    [string]$TargetFolder,
    
    [Parameter(Mandatory = $false)]
    [ValidateSet("Dev", "Test", "Prod")]
    [string]$Environment = "Dev",
    
    [Parameter(Mandatory = $false)]
    [string]$ConfigFile = "Deploy\Config\deployment-config.json",
    
    [Parameter(Mandatory = $false)]
    [System.Management.Automation.PSCredential]$Credential,
    
    [Parameter(Mandatory = $false)]
    [string]$User,
    
    [Parameter(Mandatory = $false)]
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Backward compatibility')]
    [string]$Password,
    
    [Parameter(Mandatory = $false)]
    [switch]$PromptForCredentials,
    
    [Parameter(Mandatory = $false)]
    [switch]$Force,
    
    [Parameter(Mandatory = $false)]
    [switch]$WhatIf
)

# ======================================================================
# INITIALIZATION AND SETUP
# ======================================================================

$ErrorActionPreference = "Stop"
$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$LogPath = Join-Path $ScriptPath "Logs"
$TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
$LogFile = Join-Path $LogPath "SSRS_Deployment_$TimeStamp.log"

# Ensure log directory exists
if (!(Test-Path $LogPath)) {
    New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
}

# Load SSRS Core Functions at script level
$SSRSCorePath = Join-Path $ScriptPath "SSRS-Core-Functions.ps1"
if (Test-Path $SSRSCorePath) {
    . $SSRSCorePath
} else {
    Write-Error "SSRS Core Functions file not found: $SSRSCorePath"
    exit 1
}

# ======================================================================
# LOGGING FUNCTIONS
# ======================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    
    # Color coding for console output
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
    }
    
    # Write to log file
    Add-Content -Path $LogFile -Value $LogMessage
}

function Write-Banner {
    param([string]$Title)
    
    $Banner = @"

============================================================================
$Title
============================================================================
"@
    Write-Log $Banner
}

# ======================================================================
# CONFIGURATION MANAGEMENT
# ======================================================================

function Get-DeploymentConfig {
    param([string]$ConfigFilePath)
    
    Write-Log "Loading deployment configuration from: $ConfigFilePath" -Level "INFO"
    
    if (!(Test-Path $ConfigFilePath)) {
        Write-Log "Configuration file not found. Creating default configuration..." -Level "WARNING"
        return New-DefaultConfig -ConfigPath $ConfigFilePath
    }
    
    try {
        $Config = Get-Content $ConfigFilePath -Raw | ConvertFrom-Json
        Write-Log "Configuration loaded successfully" -Level "SUCCESS"
        return $Config
    }
    catch {
        Write-Log "Failed to load configuration: $($_.Exception.Message)" -Level "ERROR"
        throw
    }
}

function New-DefaultConfig {
    param([string]$ConfigPath)
    
    $DefaultConfig = @{
        DataSources = @{
            DefaultConnectionStrings = @{
                Dev  = "Data Source=DevServer;Initial Catalog=DevDB;Integrated Security=True"
                Test = "Data Source=TestServer;Initial Catalog=TestDB;Integrated Security=True"
                Prod = "Data Source=ProdServer;Initial Catalog=ProdDB;Integrated Security=True"
            }
            Extension = "SQL"
            CredentialRetrieval = "Integrated"
        }
        Deployment = @{
            CreateFolders = $true
            OverwriteExisting = @{
                DataSources = $true
                DataSets = $true
                Reports = $true
            }
            CreateDataSources = $true
            CreateDataSets = $true
            CreateReports = $true
        }
        Folders = @{
            Reports = "/Reports"
            DataSources = "/Data Sources"
            DataSets = "/DataSets"
        }
        Security = @{
            Authentication = @{
                UseCurrentUser = $true
                PromptForCredentials = $false
                Domain = ""
                Username = ""
            }
        }
        Environments = @{
            Dev = @{
                ReportServerUrl = "http://localhost/ReportServer"
                ReportManagerUrl = "http://localhost/Reports"
            }
            Test = @{
                ReportServerUrl = "http://testserver/ReportServer"
                ReportManagerUrl = "http://testserver/Reports"
            }
            Prod = @{
                ReportServerUrl = "http://prodserver/ReportServer"
                ReportManagerUrl = "http://prodserver/Reports"
            }
        }
    }
    
    $ConfigDir = Split-Path -Parent $ConfigPath
    if (!(Test-Path $ConfigDir)) {
        New-Item -ItemType Directory -Path $ConfigDir -Force | Out-Null
    }
    
    $DefaultConfig | ConvertTo-Json -Depth 10 | Out-File $ConfigPath -Encoding UTF8
    Write-Log "Default configuration created at: $ConfigPath" -Level "INFO"
    
    return $DefaultConfig
}

# ======================================================================
# SSRS CONNECTION AND VALIDATION
# ======================================================================

function Test-SSRSConnection {
    param(
        [string]$ServerUrl,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Log "Testing connection to SSRS server: $ServerUrl" -Level "INFO"
    
    try {
        if ($Credential) {
            Write-Log "Connecting with provided credentials for user: $($Credential.UserName)" -Level "INFO"
            Connect-RsReportServer -ReportServerUri $ServerUrl -Credential $Credential
        } else {
            Write-Log "Connecting with current user Windows authentication" -Level "INFO"
            Connect-RsReportServer -ReportServerUri $ServerUrl
        }
        
        # Test the connection by getting server version
        $null = Get-RsFolderContent -RsFolder "/"
        Write-Log "Successfully connected to SSRS server" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to connect to SSRS server: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ======================================================================
# DATA SOURCE DEPLOYMENT
# ======================================================================

function Publish-DataSources {
    param(
        [object]$Config,
        [string]$Environment,
        [string]$DataSourcesPath,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Banner "DEPLOYING DATA SOURCES"
    
    if (!(Test-Path $DataSourcesPath)) {
        Write-Log "Data sources directory not found: $DataSourcesPath" -Level "WARNING"
        return
    }
    
    # Create data sources folder
    $DataSourcesFolder = "/Data Sources"
    if ($Config.Deployment.CreateFolders) {
        New-SSRSFolder -FolderPath $DataSourcesFolder
    }
    
    # Deploy .rds files by parsing them and creating data sources programmatically
    $DataSourceFiles = Get-ChildItem -Path $DataSourcesPath -Filter "*.rds" -ErrorAction SilentlyContinue
    
    if ($DataSourceFiles.Count -eq 0) {
        Write-Log "No data source files found in: $DataSourcesPath" -Level "INFO"
        return
    }
    
    foreach ($DataSourceFile in $DataSourceFiles) {
        try {
            Write-Log "Deploying data source: $($DataSourceFile.Name)" -Level "INFO"
            
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy data source $($DataSourceFile.Name)" -Level "INFO"
                continue
            }
            
            # Parse the RDS file to extract connection information
            [xml]$RdsContent = Get-Content $DataSourceFile.FullName
            $DataSourceName = $RdsContent.RptDataSource.Name
            $Extension = $RdsContent.RptDataSource.ConnectionProperties.Extension
            
            # Use connection string from config if available, otherwise use the one from file
            $ConnectionString = if ($Config.DataSources.DefaultConnectionStrings.$Environment) {
                $Config.DataSources.DefaultConnectionStrings.$Environment
            } else {
                $RdsContent.RptDataSource.ConnectionProperties.ConnectString
            }
            
            # Determine credential retrieval method
            $CredentialRetrieval = if ($RdsContent.RptDataSource.ConnectionProperties.IntegratedSecurity -eq "true") {
                "Integrated"
            } else {
                $Config.DataSources.CredentialRetrieval
            }
            
            # Create the data source using the programmatic method
            $DeployResult = New-RsDataSource -Name $DataSourceName -RsFolder $DataSourcesFolder -Extension $Extension -ConnectionString $ConnectionString -CredentialRetrieval $CredentialRetrieval -Overwrite:$Config.Deployment.OverwriteExisting.DataSources
            
            # Check if item was skipped or deployed
            if ($DeployResult.WasSkipped) {
                Write-Log "Skipped existing data source: $DataSourceName (OverwriteExisting.DataSources = false)" -Level "INFO"
            } else {
                Write-Log "Successfully deployed data source: $DataSourceName" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Failed to deploy data source $($DataSourceFile.Name): $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

# ======================================================================
# DATA SET DEPLOYMENT
# ======================================================================

function Publish-DataSets {
    param(
        [object]$Config,
        [string]$DataSetsPath,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Banner "DEPLOYING DATA SETS"
    
    if (!(Test-Path $DataSetsPath)) {
        Write-Log "Data sets directory not found: $DataSetsPath" -Level "WARNING"
        return
    }
    
    $DataSetFiles = Get-ChildItem -Path $DataSetsPath -Filter "*.rsd" -ErrorAction SilentlyContinue
    
    if ($DataSetFiles.Count -eq 0) {
        Write-Log "No data set files found in: $DataSetsPath" -Level "INFO"
        return
    }
    
    # Create data source mappings from deployed data sources
    $DataSourceMappings = @{}
    $DataSourcePath = Join-Path (Split-Path $DataSetsPath -Parent) "Data Sources"
    if (Test-Path $DataSourcePath) {
        $DataSourceFiles = Get-ChildItem -Path $DataSourcePath -Filter "*.rds" -ErrorAction SilentlyContinue
        foreach ($File in $DataSourceFiles) {
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
            $DataSourceMappings[$BaseName] = "/Data Sources/$BaseName"
        }
        Write-Log "Created data source mappings for $($DataSourceMappings.Count) data sources" -Level "INFO"
    }
    
    # Create data sets folder
    $DataSetsFolder = "/DataSets"
    if ($Config.Deployment.CreateFolders) {
        New-SSRSFolder -FolderPath $DataSetsFolder
    }
    
    foreach ($DataSetFile in $DataSetFiles) {
        try {
            $DataSetName = [System.IO.Path]::GetFileNameWithoutExtension($DataSetFile.Name)
            Write-Log "Deploying data set: $($DataSetFile.Name)" -Level "INFO"
            
            # Read and analyze RSD content
            [xml]$RsdContent = Get-Content -Path $DataSetFile.FullName -Raw
            
            # Analyze current references
            $References = Get-RsdReferences -RsdContent $RsdContent
            
            if ($References.DataSources.Count -gt 0) {
                Write-Log "  Current references:" -Level "INFO"
                foreach ($DataSource in $References.DataSources) {
                    Write-Log "    Data Source: $($DataSource.Name) ($($DataSource.Type)) → $($DataSource.Reference)" -Level "INFO"
                }
            }
            
            # Update references
            $UpdateResult = Update-RsdReferences -RsdContent $RsdContent -DataSourceMappings $DataSourceMappings -DataSetName $DataSetName
            
            if ($UpdateResult.Updated) {
                Write-Log "  Updated references in RSD file" -Level "INFO"
                
                # Save updated content to temporary file with proper encoding
                $TempFile = [System.IO.Path]::GetTempFileName()
                $TempRsdFile = [System.IO.Path]::ChangeExtension($TempFile, ".rsd")
                Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
                
                # Create XML writer settings to preserve proper format
                $XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
                $XmlWriterSettings.Indent = $true
                $XmlWriterSettings.IndentChars = "  "
                $XmlWriterSettings.Encoding = [System.Text.Encoding]::UTF8
                $XmlWriterSettings.OmitXmlDeclaration = $false
                
                $XmlWriter = [System.Xml.XmlWriter]::Create($TempRsdFile, $XmlWriterSettings)
                $UpdateResult.Content.WriteTo($XmlWriter)
                $XmlWriter.Close()
                
                $UpdatedRsdPath = $TempRsdFile
            } else {
                Write-Log "  No reference updates needed" -Level "INFO"
                $UpdatedRsdPath = $DataSetFile.FullName
            }
            
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy data set $($DataSetFile.Name)" -Level "INFO"
                if ($UpdateResult.Updated) {
                    Remove-Item -Path $TempRsdFile -Force -ErrorAction SilentlyContinue
                }
                continue
            }
            
            # Deploy the data set file with updated references
            $DeployResult = Write-RsCatalogItem -Path $UpdatedRsdPath -RsFolder $DataSetsFolder -Name $DataSetName -Overwrite:$Config.Deployment.OverwriteExisting.DataSets
            
            # Clean up temporary file if created
            if ($UpdateResult.Updated) {
                Remove-Item -Path $TempRsdFile -Force -ErrorAction SilentlyContinue
            }
            
            # Check if item was skipped or deployed
            if ($DeployResult.WasSkipped) {
                Write-Log "Skipped existing data set: $($DataSetFile.Name) (OverwriteExisting.DataSets = false)" -Level "INFO"
            } else {
                Write-Log "Successfully deployed data set: $($DataSetFile.Name)" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Failed to deploy data set $($DataSetFile.Name): $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

# ======================================================================
# REPORT DEPLOYMENT
# ======================================================================

function Publish-Reports {
    param(
        [object]$Config,
        [string]$ReportsPath,
        [string]$TargetFolder,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Banner "DEPLOYING REPORTS"
    
    if (!(Test-Path $ReportsPath)) {
        Write-Log "Reports directory not found: $ReportsPath" -Level "WARNING"
        return
    }
    
    $ReportFiles = Get-ChildItem -Path $ReportsPath -Filter "*.rdl" -Recurse
    
    if ($ReportFiles.Count -eq 0) {
        Write-Log "No report files found in: $ReportsPath" -Level "INFO"
        return
    }
    
    Write-Log "Found $($ReportFiles.Count) RDL files to process" -Level "INFO"
    
    # Create reference mappings based on available data sources and datasets
    $DataSourceMappings = @{}
    $DataSetMappings = @{}
    
    # Build mappings from available files
    $DataSourcePath = Join-Path $ScriptPath "Deploy\Data Sources"
    if (Test-Path $DataSourcePath) {
        $DataSourceFiles = Get-ChildItem -Path $DataSourcePath -Filter "*.rds"
        foreach ($File in $DataSourceFiles) {
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
            $DataSourceMappings[$BaseName] = "/Data Sources/$BaseName"
        }
        Write-Log "Created data source mappings for $($DataSourceMappings.Count) data sources" -Level "INFO"
    }
    
    $DataSetPath = Join-Path $ScriptPath "Deploy\DataSets"
    if (Test-Path $DataSetPath) {
        $DataSetFiles = Get-ChildItem -Path $DataSetPath -Filter "*.rsd"
        foreach ($File in $DataSetFiles) {
            $BaseName = [System.IO.Path]::GetFileNameWithoutExtension($File.Name)
            $DataSetMappings[$BaseName] = "/DataSets/$BaseName"
        }
        Write-Log "Created dataset mappings for $($DataSetMappings.Count) datasets" -Level "INFO"
    }

    # Use root folder if target folder is root
    $ResolvedTargetFolder = if ($TargetFolder -eq "/") {
        ""  # Empty string for root deployment
    } else {
        $TargetFolder
    }
    
    # Create target folder (only if not root)
    if ($Config.Deployment.CreateFolders -and $ResolvedTargetFolder -ne "/" -and $ResolvedTargetFolder) {
        New-SSRSFolder -FolderPath $ResolvedTargetFolder
    }
    
    foreach ($ReportFile in $ReportFiles) {
        try {
            $ReportName = [System.IO.Path]::GetFileNameWithoutExtension($ReportFile.Name)
            Write-Log "Deploying report: $($ReportFile.Name)" -Level "INFO"
            
            # Read and analyze RDL content
            [xml]$RdlContent = Get-Content -Path $ReportFile.FullName -Raw
            
            # Analyze current references
            $References = Get-RdlReferences -RdlContent $RdlContent
            
            if ($References.DataSources.Count -gt 0 -or $References.DataSets.Count -gt 0) {
                Write-Log "  Current references:" -Level "INFO"
                foreach ($DataSource in $References.DataSources) {
                    Write-Log "    Data Source: $($DataSource.Name) ($($DataSource.Type)) → $($DataSource.Reference)" -Level "INFO"
                }
                foreach ($DataSet in $References.DataSets) {
                    Write-Log "    Dataset: $($DataSet.Name) ($($DataSet.Type)) → $($DataSet.Reference)" -Level "INFO"
                }
            }
            
            # Update references
            $UpdateResult = Update-RdlReferences -RdlContent $RdlContent -DataSourceMappings $DataSourceMappings -DataSetMappings $DataSetMappings
            
            if ($UpdateResult.Updated) {
                Write-Log "  Updated references in RDL file" -Level "INFO"
                
                # Save updated content to temporary file with proper encoding
                $TempFile = [System.IO.Path]::GetTempFileName()
                $TempRdlFile = [System.IO.Path]::ChangeExtension($TempFile, ".rdl")
                Remove-Item -Path $TempFile -Force -ErrorAction SilentlyContinue
                
                # Create XML writer settings to preserve proper format
                $XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
                $XmlWriterSettings.Indent = $true
                $XmlWriterSettings.IndentChars = "  "
                $XmlWriterSettings.Encoding = [System.Text.Encoding]::UTF8
                $XmlWriterSettings.OmitXmlDeclaration = $false
                
                $XmlWriter = [System.Xml.XmlWriter]::Create($TempRdlFile, $XmlWriterSettings)
                $UpdateResult.Content.WriteTo($XmlWriter)
                $XmlWriter.Close()
                
                $UpdatedRdlPath = $TempRdlFile
            } else {
                Write-Log "  No reference updates needed" -Level "INFO"
                $UpdatedRdlPath = $ReportFile.FullName
            }
            
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy report $($ReportFile.Name)" -Level "INFO"
                if ($UpdateResult.Updated) {
                    Remove-Item -Path $TempRdlFile -Force -ErrorAction SilentlyContinue
                }
                continue
            }
            
            # Determine target folder based on directory structure, preserving the folder hierarchy
            $RelativePath = $ReportFile.DirectoryName.Replace($ReportsPath, "").TrimStart('\').Replace('\', '/')
            
            if ($RelativePath) {
                $ReportTargetFolder = if ($ResolvedTargetFolder) { 
                    "$ResolvedTargetFolder/$RelativePath" 
                } else { 
                    "/$RelativePath" 
                }
                Write-Log "Preserving folder structure: $($ReportFile.Name) -> $ReportTargetFolder" -Level "INFO"
            } else {
                $ReportTargetFolder = if ($ResolvedTargetFolder) { 
                    $ResolvedTargetFolder 
                } else { 
                    "/" 
                }
            }
            
            # Create subfolder hierarchy if needed (skip if deploying to root)
            if ($RelativePath -and $Config.Deployment.CreateFolders -and $ReportTargetFolder -ne "/") {
                Write-Log "Creating folder hierarchy: $ReportTargetFolder" -Level "INFO"
                New-SSRSFolder -FolderPath $ReportTargetFolder
            }
            
            # Deploy the report with updated references
            $DeployResult = Write-RsCatalogItem -Path $UpdatedRdlPath -RsFolder $ReportTargetFolder -Name $ReportName -Overwrite:$Config.Deployment.OverwriteExisting.Reports
            
            # Clean up temporary file if created
            if ($UpdateResult.Updated) {
                Remove-Item -Path $TempRdlFile -Force -ErrorAction SilentlyContinue
            }
            
            # Check if item was skipped or deployed
            if ($DeployResult.WasSkipped) {
                Write-Log "Skipped existing report: $($ReportFile.Name) (OverwriteExisting.Reports = false)" -Level "INFO"
            } else {
                Write-Log "Successfully deployed report: $($ReportFile.Name)" -Level "SUCCESS"
            }
        }
        catch {
            Write-Log "Failed to deploy report $($ReportFile.Name): $($_.Exception.Message)" -Level "ERROR"
        }
    }
}

# ======================================================================
# DEPLOYMENT VALIDATION
# ======================================================================

function Test-DeploymentIntegrity {
    param(
        [string]$TargetFolder
    )
    
    Write-Banner "VALIDATING DEPLOYMENT"
    
    try {
        $DeployedItems = Get-RsFolderContent -RsFolder $TargetFolder -Recurse
        
        Write-Log "Deployment validation results:" -Level "INFO"
        Write-Log "Total items deployed: $($DeployedItems.Count)" -Level "INFO"
        
        # Show items by type
        $ItemTypes = $DeployedItems | Group-Object TypeName
        foreach ($ItemType in $ItemTypes) {
            Write-Log "  $($ItemType.Name): $($ItemType.Count) items" -Level "INFO"
        }
        
        # Show folder structure for reports
        $Reports = $DeployedItems | Where-Object { $_.TypeName -eq "Report" }
        if ($Reports) {
            Write-Log "Report folder structure:" -Level "INFO"
            foreach ($Report in $Reports) {
                Write-Log "  $($Report.Path)" -Level "INFO"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to validate deployment: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ======================================================================
# CREDENTIAL RESOLUTION
# ======================================================================

function Resolve-SSRSCredentials {
    param(
        [System.Management.Automation.PSCredential]$ProvidedCredential,
        [object]$Config,
        [switch]$PromptForCredentials,
        [string]$User,
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Backward compatibility')]
        [string]$Password
    )
    
    Write-Log "Resolving authentication credentials..." -Level "INFO"
    Write-Log "Config: UseCurrentUser=$($Config.Security.Authentication.UseCurrentUser), PromptForCredentials=$($Config.Security.Authentication.PromptForCredentials)" -Level "INFO"
    Write-Log "Parameters: PromptForCredentials=$($PromptForCredentials.IsPresent), User=$User" -Level "INFO"
    
    # Priority 1: Use provided User and Password parameters
    if ($User -and $Password) {
        Write-Log "Using provided username and password for user: $User" -Level "INFO"
        try {
            $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($User, $SecurePassword)
            return $Credential
        }
        catch {
            Write-Log "Failed to create credential from User/Password parameters: $($_.Exception.Message)" -Level "WARNING"
        }
    }
    
    # Priority 2: Use provided credential parameter
    if ($ProvidedCredential) {
        Write-Log "Using provided credential for user: $($ProvidedCredential.UserName)" -Level "INFO"
        return $ProvidedCredential
    }
    
    # Priority 3: Use current user if configured (default)
    if ($Config.Security.Authentication.UseCurrentUser -and -not $PromptForCredentials.IsPresent -and -not $Config.Security.Authentication.PromptForCredentials) {
        Write-Log "Using current user Windows authentication" -Level "INFO"
        return $null  # null means use current user context
    }
    
    # Priority 4: Check if prompt is requested or configured
    if ($PromptForCredentials.IsPresent -or $Config.Security.Authentication.PromptForCredentials) {
        Write-Log "Prompting for credentials..." -Level "INFO"
        
        try {
            $Cred = Get-Credential -Message "Enter credentials for SSRS Report Server authentication"
            if ($Cred) {
                Write-Log "Credentials provided for user: $($Cred.UserName)" -Level "INFO"
                return $Cred
            } else {
                Write-Log "Credential prompt was cancelled by user" -Level "WARNING"
                Write-Log "Deployment cannot continue without proper authentication" -Level "ERROR"
                throw "Authentication cancelled by user. Deployment stopped."
            }
        }
        catch [System.Management.Automation.ParameterBindingException] {
            Write-Log "Credential prompt was cancelled by user" -Level "WARNING"
            Write-Log "Deployment cannot continue without proper authentication" -Level "ERROR"
            throw "Authentication cancelled by user. Deployment stopped."
        }
        catch {
            Write-Log "Failed to get credentials from prompt: $($_.Exception.Message)" -Level "WARNING"
            throw "Failed to obtain credentials. Deployment stopped."
        }
    }
    
    # Priority 5: Use current user if configured (fallback)
    if ($Config.Security.Authentication.UseCurrentUser) {
        Write-Log "Using current user Windows authentication (fallback)" -Level "INFO"
        return $null  # null means use current user context
    }
    
    # Priority 5: Create credential from config if username is provided
    if ($Config.Security.Authentication.Username -and $Config.Security.Authentication.Username.Trim() -ne "") {
        Write-Log "Creating credential from configuration for user: $($Config.Security.Authentication.Username)" -Level "INFO"
        
        # Prompt for password since we shouldn't store passwords in config
        try {
            $Username = if ($Config.Security.Authentication.Domain) {
                "$($Config.Security.Authentication.Domain)\$($Config.Security.Authentication.Username)"
            } else {
                $Config.Security.Authentication.Username
            }
            
            $SecurePassword = Read-Host "Enter password for $Username" -AsSecureString
            return New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
        }
        catch {
            Write-Log "Failed to create credential from config: $($_.Exception.Message)" -Level "WARNING"
        }
    }
    
    # Fallback: Use current user
    Write-Log "Falling back to current user Windows authentication" -Level "INFO"
    return $null
}

# ======================================================================
# MAIN DEPLOYMENT FUNCTION
# ======================================================================

function Start-SSRSDeployment {
    Write-Banner "ENTERPRISE-SSRS-DEPLOYMENT-FRAMEWORK STARTED"
    
    try {
        # Load configuration first
        $Config = Get-DeploymentConfig -ConfigFilePath (Join-Path $ScriptPath $ConfigFile)
        
        # Resolve parameters from configuration if not provided
        $ResolvedReportServerUrl = if ($ReportServerUrl) { 
            $ReportServerUrl 
        } elseif ($Config.Environments.$Environment.ReportServerUrl) {
            $Config.Environments.$Environment.ReportServerUrl
        } else {
            throw "ReportServerUrl not provided and not found in configuration for environment: $Environment"
        }
        
        $ResolvedTargetFolder = if ($TargetFolder) { 
            $TargetFolder 
        } else {
            "/"  # Root folder - reports will be deployed based on RDL-Files folder structure
        }
        
        Write-Log "Deployment Parameters:" -Level "INFO"
        Write-Log "  Report Server URL: $ResolvedReportServerUrl" -Level "INFO"
        Write-Log "  Target Folder: $ResolvedTargetFolder" -Level "INFO"
        Write-Log "  Environment: $Environment" -Level "INFO"
        Write-Log "  Configuration File: $ConfigFile" -Level "INFO"
        Write-Log "  Log File: $LogFile" -Level "INFO"
        
        # Resolve credentials
        $ResolveParams = @{
            ProvidedCredential = $Credential
            Config = $Config
            User = $User
            Password = $Password
        }
        if ($PromptForCredentials.IsPresent) {
            $ResolveParams.PromptForCredentials = $true
        }
        $ResolvedCredential = Resolve-SSRSCredentials @ResolveParams
        
        if ($ResolvedCredential) {
            Write-Log "  Authentication: Using credentials for $($ResolvedCredential.UserName)" -Level "INFO"
        } else {
            Write-Log "  Authentication: Using current user Windows authentication" -Level "INFO"
        }
        
        # Test SSRS connection
        if (!(Test-SSRSConnection -ServerUrl $ResolvedReportServerUrl -Credential $ResolvedCredential)) {
            throw "Failed to connect to SSRS server"
        }
        
        # Create target folder
        if ($Config.Deployment.CreateFolders) {
            New-SSRSFolder -FolderPath $ResolvedTargetFolder
        }
        
        # Deploy components in order
        if ($Config.Deployment.CreateDataSources) {
            Publish-DataSources -Config $Config -Environment $Environment -DataSourcesPath (Join-Path $ScriptPath "Deploy\Data Sources") -Credential $ResolvedCredential
        }
        
        if ($Config.Deployment.CreateDataSets) {
            Publish-DataSets -Config $Config -DataSetsPath (Join-Path $ScriptPath "Deploy\DataSets") -Credential $ResolvedCredential
        }
        
        if ($Config.Deployment.CreateReports) {
            Publish-Reports -Config $Config -ReportsPath (Join-Path $ScriptPath "Deploy\RDL-Files") -TargetFolder $ResolvedTargetFolder -Credential $ResolvedCredential
        }
        
        # Validate deployment
        Test-DeploymentIntegrity -TargetFolder $ResolvedTargetFolder
        
        Write-Banner "SSRS DEPLOYMENT COMPLETED SUCCESSFULLY"
        Write-Log "Deployment completed successfully!" -Level "SUCCESS"
        Write-Log "Log file: $LogFile" -Level "INFO"
        
        # Clear sensitive variables for security
        Clear-SensitiveVariables
        
    }
    catch {
        Write-Log "Deployment failed: $($_.Exception.Message)" -Level "ERROR"
        Write-Log "Check the log file for details: $LogFile" -Level "ERROR"
        throw
    }
}

# ======================================================================
# SECURITY FUNCTIONS
# ======================================================================

# Security function to clear sensitive variables
function Clear-SensitiveVariables {
    <#
    .SYNOPSIS
        Clear any variables that might contain sensitive information.
    #>
    try {
        # Clear variables that might contain passwords
        Get-Variable | Where-Object { 
            $_.Value -is [string] -and (
                $_.Value -like "*password*" -or 
                $_.Value -like "*pwd*" -or 
                $_.Value -like "*credential*"
            )
        } | ForEach-Object {
            if ($_.Name -notin @('PWD', 'PSMODULEPATH', 'PATH')) {
                Remove-Variable -Name $_.Name -Scope Global -ErrorAction SilentlyContinue
            }
        }
        
        # Ensure current location is preserved
        $null = Get-Location
        
        Write-Log "Cleared sensitive variables from memory" -Level "INFO"
    }
    catch {
        Write-Log "Warning: Could not clear all sensitive variables: $($_.Exception.Message)" -Level "WARNING"
    }
}

# ======================================================================
# SCRIPT EXECUTION
# ======================================================================

# Execute the deployment when script is run
Start-SSRSDeployment

# ======================================================================
# END OF SCRIPT
# ======================================================================
