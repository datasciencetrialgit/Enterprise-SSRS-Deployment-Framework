# ======================================================================
# SSRS Core Functions
# Standalone implementation of core SSRS functionality
# Replaces dependency on external ReportingServicesTools module
# ======================================================================

<#
.SYNOPSIS
    Core SSRS functionality for deployment operations.

.DESCRIPTION
    This script provides standalone SSRS functionality without requiring
    external dependencies like ReportingServicesTools module.
    
    Includes functions for:
    - Connecting to SSRS servers
    - Creating folders
    - Deploying reports, data sources, and datasets
    - Managing catalog items
#>

# Global variables for SSRS connection
$Global:SSRSConnection = $null
$Global:SSRSProxy = $null

# ======================================================================
# UTILITY FUNCTIONS
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
    $MaskedText = $MaskedText -replace "-Pwd\s+\S+", "-Pwd *****"
    $MaskedText = $MaskedText -replace "-Password\s+\S+", "-Password *****"
    
    # Mask common password patterns in XML/connection strings
    $MaskedText = $MaskedText -replace "password\s*=\s*[^;\s]+", "password=*****" -replace "pwd\s*=\s*[^;\s]+", "pwd=*****"
    
    # Mask authentication tokens or other sensitive patterns  
    $MaskedText = $MaskedText -replace "(?i)(password|pwd|token|secret|key)\s*[:=]\s*[^\s;,]+", "`$1=*****"
    
    return $MaskedText
}

# ======================================================================
# CORE SSRS CONNECTION FUNCTIONS
# ======================================================================

function Connect-RsReportServer {
    <#
    .SYNOPSIS
        Connect to SSRS Report Server using web service.
    
    .PARAMETER ReportServerUri
        The URL of the SSRS Report Server web service.
    
    .PARAMETER Credential
        Optional credentials for authentication.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUri,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        Write-Host "Connecting to SSRS server: $ReportServerUri" -ForegroundColor Cyan
        
        # Ensure URI ends with the web service endpoint
        if (-not $ReportServerUri.EndsWith("/ReportService2010.asmx")) {
            $ReportServerUri = $ReportServerUri.TrimEnd('/') + "/ReportService2010.asmx"
        }
        
        # Create web service proxy
        if ($Credential) {
            $Global:SSRSProxy = New-WebServiceProxy -Uri $ReportServerUri -Credential $Credential -Class "ReportingService"
        } else {
            $Global:SSRSProxy = New-WebServiceProxy -Uri $ReportServerUri -UseDefaultCredential -Class "ReportingService"
        }
        
        # Test connection by getting server info
        $null = $Global:SSRSProxy.ListChildren("/", $false)
        $Global:SSRSConnection = @{
            Uri = $ReportServerUri
            Proxy = $Global:SSRSProxy
            Connected = $true
        }
        
        Write-Host "Successfully connected to SSRS server" -ForegroundColor Green
        return $true
    }
    catch {
        $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
        Write-Host "Failed to connect to SSRS server: $MaskedError" -ForegroundColor Red
        $Global:SSRSConnection = $null
        $Global:SSRSProxy = $null
        throw
    }
}

function Assert-SSRSConnection {
    <#
    .SYNOPSIS
        Test if SSRS connection is active.
    #>
    if ($null -eq $Global:SSRSConnection -or $null -eq $Global:SSRSProxy) {
        throw "Not connected to SSRS server. Please run Connect-RsReportServer first."
    }
    return $true
}

# ======================================================================
# FOLDER MANAGEMENT FUNCTIONS
# ======================================================================

function New-RsFolder {
    <#
    .SYNOPSIS
        Create a new folder on the SSRS server.
    
    .PARAMETER FolderName
        Name of the folder to create.
    
    .PARAMETER ParentPath
        Parent path where the folder will be created.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderName,
        
        [Parameter(Mandatory = $false)]
        [string]$ParentPath = "/"
    )
    
    try {
        # Normalize parent path
        $ParentPath = $ParentPath.Replace('\', '/')
        if (-not $ParentPath.StartsWith('/')) {
            $ParentPath = '/' + $ParentPath
        }
        
        Write-Host "Creating folder: $FolderName in $ParentPath" -ForegroundColor Cyan
        
        # Check if folder already exists
        $ExistingItems = $Global:SSRSProxy.ListChildren($ParentPath, $false)
        $ExistingFolder = $ExistingItems | Where-Object { $_.Name -eq $FolderName -and $_.TypeName -eq "Folder" }
        
        if ($ExistingFolder) {
            Write-Host "Folder already exists: $FolderName" -ForegroundColor Yellow
            return $ExistingFolder
        }
        
        # Create the folder
        $NewFolder = $Global:SSRSProxy.CreateFolder($FolderName, $ParentPath, $null)
        Write-Host "Successfully created folder: $FolderName" -ForegroundColor Green
        return $NewFolder
    }
    catch {
        $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
        Write-Host "Failed to create folder: $MaskedError" -ForegroundColor Red
        throw
    }
}

function Get-RsFolderContent {
    <#
    .SYNOPSIS
        Get contents of a folder on the SSRS server.
    
    .PARAMETER RsFolder
        Path to the folder to list.
    
    .PARAMETER Recurse
        Include subfolders recursively.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$RsFolder,
        
        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )
    
    try {
        Write-Host "Getting folder content: $RsFolder" -ForegroundColor Cyan
        
        $Items = $Global:SSRSProxy.ListChildren($RsFolder, $Recurse.IsPresent)
        
        Write-Host "Found $($Items.Count) items in folder: $RsFolder" -ForegroundColor Green
        return $Items
    }
    catch {
        $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
        Write-Host "Failed to get folder content: $MaskedError" -ForegroundColor Red
        throw
    }
}

function New-SSRSFolder {
    <#
    .SYNOPSIS
        Create SSRS folder hierarchy (creates parent folders if needed).
    
    .PARAMETER FolderPath
        Full path of the folder to create.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )
    
    Assert-SSRSConnection
    
    # Normalize path
    $FolderPath = $FolderPath.Replace('\', '/').Trim('/')
    if (-not $FolderPath.StartsWith('/')) {
        $FolderPath = '/' + $FolderPath
    }
    
    Write-Host "Creating folder hierarchy for: $FolderPath" -ForegroundColor Cyan
    
    # Split path into components
    $PathParts = $FolderPath.Split('/', [StringSplitOptions]::RemoveEmptyEntries)
    $CurrentPath = ""
    
    foreach ($Part in $PathParts) {
        $ParentPath = if ($CurrentPath -eq "") { "/" } else { $CurrentPath }
        $CurrentPath = if ($CurrentPath -eq "") { "/$Part" } else { "$CurrentPath/$Part" }
        
        try {
            # Check if current folder exists by trying to get its properties
            try {
                $null = $Global:SSRSProxy.GetProperties($CurrentPath, @())
                Write-Host "  Folder already exists: $CurrentPath" -ForegroundColor Green
                continue
            }
            catch {
                # Folder doesn't exist, need to create it
                Write-Host "  Creating folder: $Part in $ParentPath" -ForegroundColor Yellow
                
                # Use the New-RsFolder function to create the folder
                New-RsFolder -FolderName $Part -ParentPath $ParentPath
                Write-Host "  Successfully created: $CurrentPath" -ForegroundColor Green
            }
        }            catch {
                $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
                Write-Host "  Error with folder ${CurrentPath}: $MaskedError" -ForegroundColor Red
            # Continue with next folder rather than failing completely
        }
    }
    
    Write-Host "Folder hierarchy creation completed for: $FolderPath" -ForegroundColor Cyan
}

# ======================================================================
# DATA SOURCE FUNCTIONS
# ======================================================================

function New-RsDataSource {
    <#
    .SYNOPSIS
        Create a new data source on the SSRS server.
    
    .PARAMETER Name
        Name of the data source.
    
    .PARAMETER RsFolder
        Target folder for the data source.
    
    .PARAMETER Extension
        Data source extension type.
    
    .PARAMETER ConnectionString
        Connection string for the data source.
    
    .PARAMETER CredentialRetrieval
        Credential retrieval method.
    
    .PARAMETER Overwrite
        Overwrite existing data source.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Name,
        
        [Parameter(Mandatory = $true)]
        [string]$RsFolder,
        
        [Parameter(Mandatory = $false)]
        [string]$Extension = "SQL",
        
        [Parameter(Mandatory = $true)]
        [string]$ConnectionString,
        
        [Parameter(Mandatory = $false)]
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'CredentialRetrieval is an SSRS enum, not a password')]
        [string]$CredentialRetrieval = "Integrated",
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$DatasourceCredentials
    )
    
    Assert-SSRSConnection
    
    try {
        Write-Host "Creating data source: $Name" -ForegroundColor Cyan
        
        # Check if data source already exists
        if (-not $Overwrite) {
            $ExistingItems = $Global:SSRSProxy.ListChildren($RsFolder, $false)
            $ExistingDS = $ExistingItems | Where-Object { $_.Name -eq $Name -and $_.TypeName -eq "DataSource" }
            
            if ($ExistingDS) {
                Write-Host "Data source already exists: $Name" -ForegroundColor Yellow
                return $ExistingDS
            }
        }
        
        # Create data source definition
        $DataSourceDefinition = New-Object -TypeName "ReportingService.DataSourceDefinition"
        $DataSourceDefinition.Extension = $Extension
        $DataSourceDefinition.ConnectionString = $ConnectionString
        
        # Set credential retrieval
        switch ($CredentialRetrieval.ToLower()) {
            "integrated" {
                $DataSourceDefinition.CredentialRetrieval = [ReportingService.CredentialRetrievalEnum]::Integrated
            }
            "store" {
                $DataSourceDefinition.CredentialRetrieval = [ReportingService.CredentialRetrievalEnum]::Store
                if ($DatasourceCredentials) {
                    $DataSourceDefinition.UserName = $DatasourceCredentials.UserName
                    $DataSourceDefinition.Password = $DatasourceCredentials.GetNetworkCredential().Password
                }
            }
            "prompt" {
                $DataSourceDefinition.CredentialRetrieval = [ReportingService.CredentialRetrievalEnum]::Prompt
            }
            "none" {
                $DataSourceDefinition.CredentialRetrieval = [ReportingService.CredentialRetrievalEnum]::None
            }
        }
        
        $DataSourceDefinition.Enabled = $true
        $DataSourceDefinition.EnabledSpecified = $true
        
        # Create the data source
        $Global:SSRSProxy.CreateDataSource($Name, $RsFolder, $Overwrite.IsPresent, $DataSourceDefinition, $null)
        
        Write-Host "Successfully created data source: $Name" -ForegroundColor Green
    }
    catch {
        $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
        Write-Host "Failed to create data source: $MaskedError" -ForegroundColor Red
        throw
    }
}

# ======================================================================
# REPORT DEPLOYMENT FUNCTIONS
# ======================================================================

function Write-RsCatalogItem {
    <#
    .SYNOPSIS
        Deploy a catalog item (report, dataset) to SSRS server.
    
    .PARAMETER Path
        Local path to the file to deploy.
    
    .PARAMETER RsFolder
        Target folder on the report server.
    
    .PARAMETER Overwrite
        Overwrite existing item.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$RsFolder,
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite
    )
    
    Assert-SSRSConnection
    
    try {
        if (-not (Test-Path $Path)) {
            throw "File not found: $Path"
        }
        
        $FileName = [System.IO.Path]::GetFileNameWithoutExtension($Path)
        $FileExtension = [System.IO.Path]::GetExtension($Path).ToLower()
        
        Write-Host "Deploying file: $FileName$FileExtension" -ForegroundColor Cyan
        
        # Read file content as byte array
        $FileBytes = [System.IO.File]::ReadAllBytes($Path)
        
        # Determine item type based on file extension
        $ItemType = switch ($FileExtension) {
            ".rdl" { "Report" }
            ".rds" { "DataSource" }
            ".rsd" { "DataSet" }
            default { "Report" }
        }
        
        # Check if item already exists
        if (-not $Overwrite) {
            $ExistingItems = $Global:SSRSProxy.ListChildren($RsFolder, $false)
            $ExistingItem = $ExistingItems | Where-Object { $_.Name -eq $FileName -and $_.TypeName -eq $ItemType }
            
            if ($ExistingItem) {
                Write-Host "Item already exists: $FileName" -ForegroundColor Yellow
                return $ExistingItem
            }
        }
        
        # Deploy the item
        $Warnings = $null
        switch ($ItemType) {
            "Report" {
                $Global:SSRSProxy.CreateCatalogItem("Report", $FileName, $RsFolder, $Overwrite.IsPresent, $FileBytes, $null, [ref]$Warnings)
            }
            "DataSet" {
                $Global:SSRSProxy.CreateCatalogItem("DataSet", $FileName, $RsFolder, $Overwrite.IsPresent, $FileBytes, $null, [ref]$Warnings)
            }
            "DataSource" {
                $Global:SSRSProxy.CreateCatalogItem("DataSource", $FileName, $RsFolder, $Overwrite.IsPresent, $FileBytes, $null, [ref]$Warnings)
            }
        }
        
        # Display warnings if any
        if ($Warnings) {
            foreach ($Warning in $Warnings) {
                Write-Host "Warning: $($Warning.Message)" -ForegroundColor Yellow
            }
        }
        
        Write-Host "Successfully deployed: $FileName" -ForegroundColor Green
    }
    catch {
        $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
        Write-Host "Failed to deploy item: $MaskedError" -ForegroundColor Red
        throw
    }
}

# ======================================================================
# UTILITY FUNCTIONS
# ======================================================================

function Get-SSRSServerInfo {
    <#
    .SYNOPSIS
        Get information about the SSRS server.
    #>
    Assert-SSRSConnection
    
    try {
        $ServerInfo = $Global:SSRSProxy.GetSystemProperties()
        return $ServerInfo
    }
    catch {
        $MaskedError = Hide-PasswordInText -Text $_.Exception.Message
        Write-Host "Failed to get server info: $MaskedError" -ForegroundColor Red
        throw
    }
}

function Disconnect-RsReportServer {
    <#
    .SYNOPSIS
        Disconnect from SSRS server.
    #>
    $Global:SSRSConnection = $null
    $Global:SSRSProxy = $null
    Write-Host "Disconnected from SSRS server" -ForegroundColor Green
}

# ======================================================================
# INITIALIZATION
# ======================================================================

Write-Host "SSRS Core Functions loaded successfully!" -ForegroundColor Green
Write-Host "Available functions:" -ForegroundColor Cyan
Write-Host "  - Connect-RsReportServer" -ForegroundColor White
Write-Host "  - New-RsFolder" -ForegroundColor White
Write-Host "  - Get-RsFolderContent" -ForegroundColor White
Write-Host "  - New-SSRSFolder" -ForegroundColor White
Write-Host "  - New-RsDataSource" -ForegroundColor White
Write-Host "  - Write-RsCatalogItem" -ForegroundColor White
Write-Host "  - Get-SSRSServerInfo" -ForegroundColor White
Write-Host "  - Disconnect-RsReportServer" -ForegroundColor White
