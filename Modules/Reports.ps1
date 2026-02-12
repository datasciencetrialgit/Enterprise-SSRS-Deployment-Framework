# ======================================================================
# Enterprise-SSRS-Deployment-Framework - Reports Module
# Contains report deployment functions
# ======================================================================

function Publish-Reports {
    param(
        [object]$Config,
        [string]$ReportsPath,
        [string]$TargetFolder,
        [System.Management.Automation.PSCredential]$Credential,
        [string]$ScriptPath,
        [switch]$WhatIf
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

# Functions are available when dot-sourced
