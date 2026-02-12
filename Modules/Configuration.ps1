# ======================================================================
# Enterprise-SSRS-Deployment-Framework - Configuration Module
# Contains configuration management functions
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

# Functions are available when dot-sourced
