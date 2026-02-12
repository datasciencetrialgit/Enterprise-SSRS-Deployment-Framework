# ======================================================================
# Enterprise-SSRS-Deployment-Framework - DataSets Module
# Contains dataset deployment functions
# ======================================================================

function Publish-DataSets {
    param(
        [object]$Config,
        [string]$DataSetsPath,
        [System.Management.Automation.PSCredential]$Credential,
        [switch]$WhatIf
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

# Functions are available when dot-sourced
