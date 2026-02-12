# ======================================================================
# Enterprise-SSRS-Deployment-Framework - DataSources Module
# Contains data source deployment functions
# ======================================================================

function Publish-DataSources {
    param(
        [object]$Config,
        [string]$Environment,
        [string]$DataSourcesPath,
        [System.Management.Automation.PSCredential]$Credential,
        [switch]$WhatIf
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

# Functions are available when dot-sourced
