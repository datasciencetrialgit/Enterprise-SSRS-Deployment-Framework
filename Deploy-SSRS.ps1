# ======================================================================
# SSRS Deployment Package
# PowerShell Script for deploying SSRS Reports, DataSources, and DataSets
# Based on Microsoft ReportingServicesTools
# ======================================================================

<#
.SYNOPSIS
    Comprehensive SSRS Deployment Package for deploying reports, data sources, and datasets.

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

.EXAMPLE
    .\Deploy-SSRS.ps1
    Deploys using configuration values for Dev environment

.EXAMPLE
    .\Deploy-SSRS.ps1 -Environment "Prod"
    Deploys using configuration values for Prod environment

.EXAMPLE
    .\Deploy-SSRS.ps1 -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/MyReports" -Environment "Dev"
    Deploys with explicit parameters, overriding configuration values

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
    [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Backward compatibility - password is masked in logs')]
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

function Hide-PasswordInText {
    <#
    .SYNOPSIS
        Masks potential passwords in text to prevent them from appearing in logs or console output.
    
    .PARAMETER Text
        The text to mask passwords in.
    #>
    param(
        [string]$Text
    )
    
    if ([string]::IsNullOrEmpty($Text)) {
        return $Text
    }
    
    # Mask various password patterns
    $MaskedText = $Text
    
    # Mask specific known test passwords (add test passwords here, not real ones)
    $MaskedText = $MaskedText -replace "TestPassword123", "*****"
    
    # Mask command-line password parameters
    $MaskedText = $MaskedText -replace "-Password\s+\S+", "-Password *****"
    $MaskedText = $MaskedText -replace "-Password\s+\S+", "-Password *****"
    
    # Mask common password patterns in XML/connection strings
    $MaskedText = $MaskedText -replace "password\s*=\s*[^;\s]+", "password=*****" -replace "pwd\s*=\s*[^;\s]+", "pwd=*****"
    
    # Mask authentication tokens or other sensitive patterns
    $MaskedText = $MaskedText -replace "(?i)(password|pwd|token|secret|key)\s*[:=]\s*[^\s;,]+", "`$1=*****"
    
    return $MaskedText
}

# Add password masking for error logging
function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    # Mask any potential passwords in log messages
    $SafeMessage = Hide-PasswordInText -Text $Message
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $SafeMessage"
    
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
            OverwriteExisting = $true
            CreateDataSources = $true
            CreateDataSets = $true
            CreateReports = $true
        }
        Folders = @{
            Reports = "/Reports"
            DataSources = "/Data Sources"
            DataSets = "/DataSets"
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
    
    $DataSourceFiles = Get-ChildItem -Path $DataSourcesPath -Filter "*.rds" -ErrorAction SilentlyContinue
    
    if ($DataSourceFiles.Count -eq 0) {
        Write-Log "No data source files found in: $DataSourcesPath" -Level "INFO"
        return
    }
    
    # Create data sources folder
    if ($Config.Deployment.CreateFolders) {
        New-SSRSFolder -FolderPath "/Data Sources"
    }
    
    foreach ($DataSourceFile in $DataSourceFiles) {
        try {
            Write-Log "Deploying data source: $($DataSourceFile.Name)" -Level "INFO"
            
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy data source $($DataSourceFile.Name)" -Level "INFO"
                continue
            }
            
            # Deploy the data source file
            Write-RsCatalogItem -Path $DataSourceFile.FullName -RsFolder "/Data Sources" -Overwrite:$Config.Deployment.OverwriteExisting
            
            Write-Log "Successfully deployed data source: $($DataSourceFile.Name)" -Level "SUCCESS"
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
    
    # Create data sets folder
    if ($Config.Deployment.CreateFolders) {
        New-SSRSFolder -FolderPath "/DataSets"
    }
    
    foreach ($DataSetFile in $DataSetFiles) {
        try {
            Write-Log "Deploying data set: $($DataSetFile.Name)" -Level "INFO"
            
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy data set $($DataSetFile.Name)" -Level "INFO"
                continue
            }
            
            # Deploy the data set file
            Write-RsCatalogItem -Path $DataSetFile.FullName -RsFolder "/DataSets" -Overwrite:$Config.Deployment.OverwriteExisting
            
            Write-Log "Successfully deployed data set: $($DataSetFile.Name)" -Level "SUCCESS"
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
    
    # Create target folder
    if ($Config.Deployment.CreateFolders) {
        New-SSRSFolder -FolderPath $TargetFolder
    }
    
    foreach ($ReportFile in $ReportFiles) {
        try {
            Write-Log "Deploying report: $($ReportFile.Name)" -Level "INFO"
            
            if ($WhatIf) {
                Write-Log "WhatIf: Would deploy report $($ReportFile.Name)" -Level "INFO"
                continue
            }
            
            # Determine target folder based on directory structure
            $RelativePath = $ReportFile.DirectoryName.Replace($ReportsPath, "").Replace("\", "/")
            $ReportTargetFolder = if ($RelativePath) { 
                "$TargetFolder$RelativePath" 
            } else { 
                $TargetFolder 
            }
            
            # Create subfolder if needed
            if ($RelativePath) {
                New-SSRSFolder -FolderPath $ReportTargetFolder
            }
            
            # Deploy the report
            Write-RsCatalogItem -Path $ReportFile.FullName -RsFolder $ReportTargetFolder -Overwrite:$Config.Deployment.OverwriteExisting
            
            Write-Log "Successfully deployed report: $($ReportFile.Name)" -Level "SUCCESS"
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
        
        $ItemTypes = $DeployedItems | Group-Object TypeName
        foreach ($ItemType in $ItemTypes) {
            Write-Log "  $($ItemType.Name): $($ItemType.Count) items" -Level "INFO"
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
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Backward compatibility - password is masked in logs')]
        [string]$Password
    )
    
    Write-Log "Resolving authentication credentials..." -Level "INFO"
    
    # Priority 1: Use provided User and Password parameters
    if ($User -and $Password) {
        Write-Log "Using provided username and password for user: $User (password masked)" -Level "INFO"
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
    if ($Config.Security.Authentication.UseCurrentUser -and -not $PromptForCredentials -and -not $Config.Security.Authentication.PromptForCredentials) {
        Write-Log "Using current user Windows authentication" -Level "INFO"
        return $null  # null means use current user context
    }
    
    # Priority 4: Check if prompt is requested or configured
    if ($PromptForCredentials -or $Config.Security.Authentication.PromptForCredentials) {
        Write-Log "Prompting for credentials..." -Level "INFO"
        
        try {
            $Cred = Get-Credential -Message "Enter credentials for SSRS Report Server authentication"
            if ($Cred) {
                Write-Log "Credentials provided for user: $($Cred.UserName)" -Level "INFO"
                return $Cred
            }
        }
        catch {
            Write-Log "Failed to get credentials from prompt: $($_.Exception.Message)" -Level "WARNING"
        }
    }
    
    # Priority 5: Use current user if configured (fallback)
    if ($Config.Security.Authentication.UseCurrentUser) {
        Write-Log "Using current user Windows authentication (fallback)" -Level "INFO"
        return $null  # null means use current user context
    }
    
    # Priority 5: Create credential from config if username is provided
    if ($Config.Security.Authentication.Username) {
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
    Write-Banner "SSRS DEPLOYMENT PACKAGE STARTED"
    
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
            "/"  # Deploy to root, subfolders will be created based on RDL-Files structure
        }
        
        Write-Log "Deployment Parameters:" -Level "INFO"
        Write-Log "  Report Server URL: $ResolvedReportServerUrl" -Level "INFO"
        Write-Log "  Target Folder: $ResolvedTargetFolder" -Level "INFO"
        Write-Log "  Environment: $Environment" -Level "INFO"
        Write-Log "  Configuration File: $ConfigFile" -Level "INFO"
        Write-Log "  Log File: $LogFile" -Level "INFO"
        
        # Resolve credentials
        $ResolvedCredential = Resolve-SSRSCredentials -ProvidedCredential $Credential -Config $Config -PromptForCredentials $PromptForCredentials -User $User -Password $Password
        
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
            Publish-DataSources -Config $Config -Environment $Environment -DataSourcesPath (Join-Path $ScriptPath "Deploy\DataSources") -Credential $ResolvedCredential
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
