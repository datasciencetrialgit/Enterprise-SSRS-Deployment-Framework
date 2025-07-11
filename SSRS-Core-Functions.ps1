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
        Write-Host "Failed to connect to SSRS server: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "Failed to create folder: $($_.Exception.Message)" -ForegroundColor Red
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
        Write-Host "Failed to get folder content: $($_.Exception.Message)" -ForegroundColor Red
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
        }
        catch {
            Write-Host "  Error with folder ${CurrentPath}: $($_.Exception.Message)" -ForegroundColor Red
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
                Write-Host "Data source already exists, skipping deployment: $Name" -ForegroundColor Yellow
                # Add metadata to indicate this was skipped
                $ExistingDS | Add-Member -NotePropertyName "WasSkipped" -NotePropertyValue $true -Force
                return $ExistingDS
            }
        }
        
        # Create data source definition
        $DataSourceDefinition = New-Object -TypeName "$($Global:SSRSProxy.GetType().Namespace).DataSourceDefinition"
        $DataSourceDefinition.Extension = $Extension
        $DataSourceDefinition.ConnectString = $ConnectionString
        
        # Set credential retrieval using the proxy's enum types
        $CredentialRetrievalEnum = "$($Global:SSRSProxy.GetType().Namespace).CredentialRetrievalEnum" -as [Type]
        switch ($CredentialRetrieval.ToLower()) {
            "integrated" {
                $DataSourceDefinition.CredentialRetrieval = [Enum]::Parse($CredentialRetrievalEnum, "Integrated")
            }
            "store" {
                $DataSourceDefinition.CredentialRetrieval = [Enum]::Parse($CredentialRetrievalEnum, "Store")
                if ($DatasourceCredentials) {
                    $DataSourceDefinition.UserName = $DatasourceCredentials.UserName
                    $DataSourceDefinition.Password = $DatasourceCredentials.GetNetworkCredential().Password
                }
            }
            "prompt" {
                $DataSourceDefinition.CredentialRetrieval = [Enum]::Parse($CredentialRetrievalEnum, "Prompt")
            }
            "none" {
                $DataSourceDefinition.CredentialRetrieval = [Enum]::Parse($CredentialRetrievalEnum, "None")
            }
        }
        
        $DataSourceDefinition.Enabled = $true
        $DataSourceDefinition.EnabledSpecified = $true
        
        # Create the data source
        $Global:SSRSProxy.CreateDataSource($Name, $RsFolder, $Overwrite.IsPresent, $DataSourceDefinition, $null)
        
        Write-Host "Successfully created data source: $Name" -ForegroundColor Green
    }
    catch {
        Write-Host "Failed to create data source: $($_.Exception.Message)" -ForegroundColor Red
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
    
    .PARAMETER Name
        Optional name for the item on SSRS. If not provided, uses the filename.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Path,
        
        [Parameter(Mandatory = $true)]
        [string]$RsFolder,
        
        [Parameter(Mandatory = $false)]
        [switch]$Overwrite,
        
        [Parameter(Mandatory = $false)]
        [string]$Name
    )
    
    Assert-SSRSConnection
    
    try {
        if (-not (Test-Path $Path)) {
            throw "File not found: $Path"
        }
        
        $FileName = if ($Name) { $Name } else { [System.IO.Path]::GetFileNameWithoutExtension($Path) }
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
                Write-Host "$ItemType already exists, skipping deployment: $FileName" -ForegroundColor Yellow
                # Add metadata to indicate this was skipped
                $ExistingItem | Add-Member -NotePropertyName "WasSkipped" -NotePropertyValue $true -Force
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
        Write-Host "Failed to deploy item: $($_.Exception.Message)" -ForegroundColor Red
        throw
    }
}

# ======================================================================
# RDL REFERENCE MANAGEMENT FUNCTIONS
# ======================================================================

function Update-RdlReferences {
    <#
    .SYNOPSIS
        Updates data source and dataset references in RDL files for SSRS deployment.
    
    .DESCRIPTION
        Modifies RDL XML to update data source and dataset references from Visual Studio
        development references to proper SSRS folder paths.
    
    .PARAMETER RdlContent
        The RDL file content as XML.
    
    .PARAMETER DataSourceMappings
        Hashtable mapping data source names to their SSRS paths.
    
    .PARAMETER DataSetMappings
        Hashtable mapping dataset names to their SSRS paths.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [xml]$RdlContent,
        
        [Parameter(Mandatory = $false)]
        [hashtable]$DataSourceMappings = @{},
        
        [Parameter(Mandatory = $false)]
        [hashtable]$DataSetMappings = @{}
    )
    
    try {
        $Updated = $false
        
        # Define namespaces for RDL XML
        $NamespaceManager = New-Object System.Xml.XmlNamespaceManager($RdlContent.NameTable)
        $NamespaceManager.AddNamespace("rd", "http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition")
        $NamespaceManager.AddNamespace("rd2010", "http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition")
        $NamespaceManager.AddNamespace("rd2005", "http://schemas.microsoft.com/sqlserver/reporting/2005/01/reportdefinition")
        
        # Try different namespace versions
        $Namespaces = @("rd", "rd2010", "rd2005")
        
        foreach ($ns in $Namespaces) {
            # Update Data Source References
            $DataSourceNodes = $RdlContent.SelectNodes("//$ns`:DataSources/$ns`:DataSource/$ns`:DataSourceReference", $NamespaceManager)
            foreach ($Node in $DataSourceNodes) {
                $OriginalRef = $Node.InnerText
                if ($DataSourceMappings.ContainsKey($OriginalRef)) {
                    $NewRef = $DataSourceMappings[$OriginalRef]
                    Write-Host "    Updating data source reference: '$OriginalRef' → '$NewRef'" -ForegroundColor Yellow
                    $Node.InnerText = $NewRef
                    $Updated = $true
                }
                elseif (-not $OriginalRef.StartsWith("/")) {
                    # Auto-map to /Data Sources/ folder
                    $NewRef = "/Data Sources/$OriginalRef"
                    Write-Host "    Auto-mapping data source reference: '$OriginalRef' → '$NewRef'" -ForegroundColor Yellow
                    $Node.InnerText = $NewRef
                    $Updated = $true
                }
            }
            
            # Update Data Set References
            $DataSetNodes = $RdlContent.SelectNodes("//$ns`:DataSets/$ns`:DataSet/$ns`:SharedDataSet/$ns`:SharedDataSetReference", $NamespaceManager)
            foreach ($Node in $DataSetNodes) {
                $OriginalRef = $Node.InnerText
                if ($DataSetMappings.ContainsKey($OriginalRef)) {
                    $NewRef = $DataSetMappings[$OriginalRef]
                    Write-Host "    Updating dataset reference: '$OriginalRef' → '$NewRef'" -ForegroundColor Yellow
                    $Node.InnerText = $NewRef
                    $Updated = $true
                }
                elseif (-not $OriginalRef.StartsWith("/")) {
                    # Auto-map to /DataSets/ folder
                    $NewRef = "/DataSets/$OriginalRef"
                    Write-Host "    Auto-mapping dataset reference: '$OriginalRef' → '$NewRef'" -ForegroundColor Yellow
                    $Node.InnerText = $NewRef
                    $Updated = $true
                }
            }
            
            # Update embedded data source connection references
            $EmbeddedDataSourceNodes = $RdlContent.SelectNodes("//$ns`:DataSources/$ns`:DataSource[not($ns`:DataSourceReference)]", $NamespaceManager)
            foreach ($Node in $EmbeddedDataSourceNodes) {
                $DataSourceName = $Node.GetAttribute("Name")
                if ($DataSourceMappings.ContainsKey($DataSourceName)) {
                    Write-Host "    Converting embedded data source '$DataSourceName' to reference" -ForegroundColor Yellow
                    
                    # Remove existing content
                    $Node.RemoveAll()
                    
                    # Add DataSourceReference
                    $RefNode = $RdlContent.CreateElement("DataSourceReference", $Node.NamespaceURI)
                    $RefNode.InnerText = $DataSourceMappings[$DataSourceName]
                    $Node.AppendChild($RefNode)
                    $Updated = $true
                }
            }
        }
        
        return @{
            Updated = $Updated
            Content = $RdlContent
        }
    }
    catch {
        Write-Host "    [ERROR] Failed to update RDL references: $($_.Exception.Message)" -ForegroundColor Red
        return @{
            Updated = $false
            Content = $RdlContent
        }
    }
}

function Get-RdlReferences {
    <#
    .SYNOPSIS
        Analyzes RDL file to extract data source and dataset references.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [xml]$RdlContent
    )
    
    $References = @{
        DataSources = @()
        DataSets = @()
    }
    
    try {
        $NamespaceManager = New-Object System.Xml.XmlNamespaceManager($RdlContent.NameTable)
        $NamespaceManager.AddNamespace("rd", "http://schemas.microsoft.com/sqlserver/reporting/2016/01/reportdefinition")
        $NamespaceManager.AddNamespace("rd2010", "http://schemas.microsoft.com/sqlserver/reporting/2010/01/reportdefinition")
        $NamespaceManager.AddNamespace("rd2005", "http://schemas.microsoft.com/sqlserver/reporting/2005/01/reportdefinition")
        
        $Namespaces = @("rd", "rd2010", "rd2005")
        
        foreach ($ns in $Namespaces) {
            # Get data source references
            $DataSourceNodes = $RdlContent.SelectNodes("//$ns`:DataSources/$ns`:DataSource", $NamespaceManager)
            foreach ($Node in $DataSourceNodes) {
                $DataSourceName = $Node.GetAttribute("Name")
                $RefNode = $Node.SelectSingleNode("$ns`:DataSourceReference", $NamespaceManager)
                if ($RefNode) {
                    $References.DataSources += @{
                        Name = $DataSourceName
                        Reference = $RefNode.InnerText
                        Type = "Reference"
                    }
                } else {
                    $References.DataSources += @{
                        Name = $DataSourceName
                        Reference = $null
                        Type = "Embedded"
                    }
                }
            }
            
            # Get dataset references
            $DataSetNodes = $RdlContent.SelectNodes("//$ns`:DataSets/$ns`:DataSet", $NamespaceManager)
            foreach ($Node in $DataSetNodes) {
                $DataSetName = $Node.GetAttribute("Name")
                $RefNode = $Node.SelectSingleNode("$ns`:SharedDataSet/$ns`:SharedDataSetReference", $NamespaceManager)
                if ($RefNode) {
                    $References.DataSets += @{
                        Name = $DataSetName
                        Reference = $RefNode.InnerText
                        Type = "Shared"
                    }
                } else {
                    $References.DataSets += @{
                        Name = $DataSetName
                        Reference = $null
                        Type = "Embedded"
                    }
                }
            }
        }
        
        return $References
    }
    catch {
        Write-Host "    [ERROR] Failed to analyze RDL references: $($_.Exception.Message)" -ForegroundColor Red
        return $References
    }
}

# ======================================================================
# RSD REFERENCE MANAGEMENT FUNCTIONS
# ======================================================================

function Update-RsdReferences {
    <#
    .SYNOPSIS
        Updates data source references in RSD (shared dataset) files for SSRS deployment.
    
    .PARAMETER RsdContent
        The XML content of the RSD file.
    
    .PARAMETER DataSourceMappings
        Hashtable mapping data source names to full SSRS paths.
    
    .PARAMETER DataSetName
        The expected name for the internal dataset (should match the RSD file name).
    
    .RETURNS
        PSObject with Updated (bool) and Content (XmlDocument) properties.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [xml]$RsdContent,
        
        [Parameter(Mandatory = $true)]
        [hashtable]$DataSourceMappings,
        
        [Parameter(Mandatory = $false)]
        [string]$DataSetName
    )
    
    $Updated = $false
    $UpdatedContent = $RsdContent.Clone()
    
    try {
        # Handle different namespace versions
        $NamespaceManager = New-Object System.Xml.XmlNamespaceManager($UpdatedContent.NameTable)
        
        # Try different namespace URIs for different SSRS versions
        $PossibleNamespaces = @(
            "http://schemas.microsoft.com/sqlserver/reporting/2010/01/shareddatasetdefinition",
            "http://schemas.microsoft.com/sqlserver/reporting/2016/01/shareddatasetdefinition"
        )
        
        $DefaultNamespace = $null
        foreach ($ns in $PossibleNamespaces) {
            if ($UpdatedContent.DocumentElement.NamespaceURI -eq $ns) {
                $DefaultNamespace = $ns
                break
            }
        }
        
        if (-not $DefaultNamespace) {
            $DefaultNamespace = $UpdatedContent.DocumentElement.NamespaceURI
        }
        
        $NamespaceManager.AddNamespace("rsd", $DefaultNamespace)
        
        # Find DataSourceReference elements
        $DataSourceRefNodes = $UpdatedContent.SelectNodes("//rsd:DataSourceReference", $NamespaceManager)
        
        foreach ($Node in $DataSourceRefNodes) {
            $CurrentRef = $Node.InnerText
            
            # Skip if already a full path
            if ($CurrentRef.StartsWith("/")) {
                continue
            }
            
            # Check if we have a mapping for this data source
            if ($DataSourceMappings.ContainsKey($CurrentRef)) {
                $NewRef = $DataSourceMappings[$CurrentRef]
                Write-Host "    Updating data source reference: '$CurrentRef' → '$NewRef'" -ForegroundColor Cyan
                $Node.InnerText = $NewRef
                $Updated = $true
            }
        }
        
        # Update internal dataset name if provided
        if ($DataSetName) {
            $DataSetNodes = $UpdatedContent.SelectNodes("//rsd:DataSet", $NamespaceManager)
            foreach ($Node in $DataSetNodes) {
                $CurrentName = $Node.GetAttribute("Name")
                if ($CurrentName -and $CurrentName -ne $DataSetName) {
                    Write-Host "    Updating internal dataset name: '$CurrentName' → '$DataSetName'" -ForegroundColor Cyan
                    $Node.SetAttribute("Name", $DataSetName)
                    $Updated = $true
                }
            }
        }
        
        # If updated, create a new XML document with proper formatting
        if ($Updated) {
            # Create XML writer settings to preserve formatting
            $StringWriter = New-Object System.IO.StringWriter
            $XmlWriterSettings = New-Object System.Xml.XmlWriterSettings
            $XmlWriterSettings.Indent = $true
            $XmlWriterSettings.IndentChars = "  "
            $XmlWriterSettings.NewLineChars = "`r`n"
            $XmlWriterSettings.Encoding = [System.Text.Encoding]::UTF8
            
            $XmlWriter = [System.Xml.XmlWriter]::Create($StringWriter, $XmlWriterSettings)
            $UpdatedContent.WriteTo($XmlWriter)
            $XmlWriter.Close()
            
            # Create new XML document from formatted string
            $FormattedXml = New-Object System.Xml.XmlDocument
            $FormattedXml.LoadXml($StringWriter.ToString())
            $StringWriter.Close()
            
            return @{
                Updated = $Updated
                Content = $FormattedXml
            }
        }
        
        return @{
            Updated = $Updated
            Content = $UpdatedContent
        }
    }
    catch {
        Write-Warning "Error updating RSD references: $($_.Exception.Message)"
        return @{
            Updated = $false
            Content = $RsdContent
        }
    }
}

function Get-RsdReferences {
    <#
    .SYNOPSIS
        Analyzes an RSD file to extract data source references.
    
    .PARAMETER RsdContent
        The XML content of the RSD file.
    
    .RETURNS
        PSObject with DataSources array property.
    #>
    param(
        [Parameter(Mandatory = $true)]
        [xml]$RsdContent
    )
    
    $DataSources = @()
    
    try {
        # Handle different namespace versions
        $NamespaceManager = New-Object System.Xml.XmlNamespaceManager($RsdContent.NameTable)
        
        # Try different namespace URIs for different SSRS versions
        $PossibleNamespaces = @(
            "http://schemas.microsoft.com/sqlserver/reporting/2010/01/shareddatasetdefinition",
            "http://schemas.microsoft.com/sqlserver/reporting/2016/01/shareddatasetdefinition"
        )
        
        $DefaultNamespace = $null
        foreach ($ns in $PossibleNamespaces) {
            if ($RsdContent.DocumentElement.NamespaceURI -eq $ns) {
                $DefaultNamespace = $ns
                break
            }
        }
        
        if (-not $DefaultNamespace) {
            $DefaultNamespace = $RsdContent.DocumentElement.NamespaceURI
        }
        
        $NamespaceManager.AddNamespace("rsd", $DefaultNamespace)
        
        # Find DataSourceReference elements
        $DataSourceRefNodes = $RsdContent.SelectNodes("//rsd:DataSourceReference", $NamespaceManager)
        
        foreach ($Node in $DataSourceRefNodes) {
            $Reference = $Node.InnerText
            $DataSources += @{
                Name = $Reference
                Reference = $Reference
                Type = "Reference"
            }
        }
        
        return @{
            DataSources = $DataSources
        }
    }
    catch {
        Write-Warning "Error analyzing RSD references: $($_.Exception.Message)"
        return @{
            DataSources = @()
        }
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
        Write-Host "Failed to get server info: $($_.Exception.Message)" -ForegroundColor Red
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
