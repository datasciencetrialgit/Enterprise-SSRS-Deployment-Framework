# Enterprise-SSRS-Deployment-Framework

A comprehensive PowerShell-based deployment solution for SQL Server Reporting Services (SSRS) with **standalone functionality** - no external dependencies required!

## 🎯 Features

- **Complete SSRS Deployment**: Deploy reports, data sources, and datasets
- **Standalone Package**: No external dependencies or module installations required
- **Environment-Based Configuration**: Support for Dev, Test, and Prod environments
- **Flexible Structure**: Organized folder structure for different component types
- **Comprehensive Logging**: Detailed logging with timestamps and color-coded output
- **Individual Component Deployment**: Helper functions for deploying single items
- **Validation and Reporting**: Post-deployment validation and inventory reporting
- **Configuration Management**: JSON-based configuration with environment-specific settings
- **Built-in SSRS Web Service Client**: Direct SSRS server communication

## 📁 Project Structure

```
SSRS-Deployment-Package/
├── Deploy-SSRS.ps1                 # Main deployment script
├── SSRS-Core-Functions.ps1         # Core SSRS web service functions
├── Setup-Package.ps1               # Package setup and verification script
├── Deploy/                         # Deployment content folder
│   ├── Config/
│   │   └── deployment-config.json  # Configuration file
│   ├── RDL-Files/                  # Place your .rdl report files here
│   ├── Data Sources/               # Place your .rds data source files here
│   └── DataSets/                   # Place your .rsd dataset files here
└── Logs/                          # Deployment logs (auto-created)
```

## 🚀 Quick Start

### 1. Prerequisites

- PowerShell 5.1 or later
- SQL Server Reporting Services 2016 or later
- Network access to SSRS Report Server
- **No additional modules required!**

### 2. Setup

1. Clone or download this deployment package
2. Run the setup script to verify everything is working:
   ```powershell
   .\Setup-Package.ps1 -CreateSampleConfig
   ```
3. Copy your SSRS files to the appropriate folders:
   - `.rdl` files → `Deploy/RDL-Files/`
   - `.rds` data source files → `Deploy/Data Sources/`
   - `.rsd` dataset files → `Deploy/DataSets/`

### 3. Authentication

The package supports multiple authentication methods:

- **Current User (Default)**: Uses your Windows credentials
- **Prompted Credentials**: Script prompts for username/password
- **Runtime Credentials**: Pass credentials as parameters

For detailed authentication configuration, see [AUTHENTICATION.md](AUTHENTICATION.md).

### 4. Configure

Edit `Deploy/Config/deployment-config.json` to match your environment:

```json
{
  "DataSources": {
    "DefaultConnectionStrings": {
      "Dev": "Data Source=localhost\\SQLEXPRESS;Initial Catalog=YourDB;Integrated Security=True",
      "Test": "Data Source=TestServer;Initial Catalog=YourDB;Integrated Security=True",
      "Prod": "Data Source=ProdServer;Initial Catalog=YourDB;Integrated Security=True"
    }
  },
  "Environments": {
    "Dev": {
      "ReportServerUrl": "http://localhost/ReportServer"
    }
  }
}
```

### 5. Deploy

```powershell
# Simplified deployment - only environment and credentials needed
# (ReportServerUrl and TargetFolder read from config file)
.\Deploy-SSRS.ps1 -Environment "Dev" -User "domain\username" -Password "yourpassword"

# Full deployment with explicit parameters (overrides config)
.\Deploy-SSRS.ps1 -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/MyReports" -Environment "Dev"

# Test deployment (WhatIf mode)
.\Deploy-SSRS.ps1 -Environment "Dev" -User "domain\username" -Password "yourpassword" -WhatIf

# Deploy with configuration file only (uses current user authentication)
.\Deploy-SSRS.ps1 -Environment "Dev"

# Deploy with credentials object
$Cred = Get-Credential
.\Deploy-SSRS.ps1 -Environment "Dev" -Credential $Cred

# Deploy with credential prompt
.\Deploy-SSRS.ps1 -Environment "Dev" -PromptForCredentials
```

## 🚀 GitHub Actions & CI/CD Integration

This package is designed to work seamlessly with GitHub Actions and other CI/CD pipelines. The `-User` and `-Password` parameters allow for automated deployments without interactive prompts.

### GitHub Actions Example

Create `.github/workflows/deploy-ssrs.yml`:

```yaml
name: Deploy SSRS Reports

on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: windows-latest
    
    steps:
    - uses: actions/checkout@v3
    
    - name: Deploy to Dev Environment
      run: |
        .\Deploy-SSRS.ps1 -Environment "Dev" -User "${{ secrets.SSRS_USERNAME }}" -Password "${{ secrets.SSRS_PASSWORD }}"
      shell: powershell
      
    - name: Deploy to Production (on main branch)
      if: github.ref == 'refs/heads/main'
      run: |
        .\Deploy-SSRS.ps1 -Environment "Prod" -User "${{ secrets.PROD_SSRS_USERNAME }}" -Password "${{ secrets.PROD_SSRS_PASSWORD }}"
      shell: powershell
```

### Required GitHub Secrets

Set these secrets in your GitHub repository (Settings → Secrets and Variables → Actions):

| Secret Name | Description | Example |
|-------------|-------------|---------|
| `SSRS_USERNAME` | SSRS service account username | `domain\svc-ssrs` |
| `SSRS_PASSWORD` | SSRS service account password | `your-secure-password` |
| `PROD_SSRS_USERNAME` | Production SSRS username | `domain\svc-ssrs-prod` |
| `PROD_SSRS_PASSWORD` | Production SSRS password | `your-prod-password` |

**Note**: ReportServerUrl and TargetFolder are automatically read from `Config/deployment-config.json` based on the Environment parameter.

### Azure DevOps Pipeline Example

```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

variables:
- group: SSRS-Variables  # Variable group containing SSRS credentials

steps:
- task: PowerShell@2
  displayName: 'Deploy SSRS Reports'
  inputs:
    targetType: 'inline'
    script: |
      .\Deploy-SSRS.ps1 -Environment "$(Environment)" -User "$(SSRS_USERNAME)" -Password "$(SSRS_PASSWORD)"
```

### Security Best Practices for CI/CD

1. **Use Service Accounts**: Create dedicated service accounts for SSRS deployments
2. **Encrypt Secrets**: Always store credentials as encrypted secrets in your CI/CD platform
3. **Least Privilege**: Grant only necessary permissions to service accounts
4. **Environment Separation**: Use different credentials for different environments
5. **Audit Logging**: Enable audit logging in SSRS to track deployment activities
```

## 📖 Usage Examples

### Full Deployment

```powershell
# Deploy everything to a specific folder
.\Deploy-SSRS.ps1 -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/Sales Reports" -Environment "Dev"
```

### Individual Component Deployment

```powershell
# Import core functions
. .\SSRS-Core-Functions.ps1

# Connect to SSRS server
Connect-RsReportServer -ReportServerUri "http://localhost/ReportServer"

# Deploy a single report
New-SSRSFolder -FolderPath "/Reports"
Write-RsCatalogItem -Path "Deploy/RDL-Files/SalesReport.rdl" -RsFolder "/Reports" -Overwrite

# Deploy a single data source
New-SSRSFolder -FolderPath "/Data Sources"
New-RsDataSource -Name "AdventureWorks" -ConnectionString "Data Source=localhost;Initial Catalog=AdventureWorks2019;Integrated Security=True" -RsFolder "/Data Sources" -Overwrite

# Deploy all files from a specific folder
Get-ChildItem "Deploy/RDL-Files/*.rdl" | ForEach-Object { 
    Write-RsCatalogItem -Path $_.FullName -RsFolder "/Reports" -Overwrite 
}
```

### Inventory and Validation

```powershell
# Get SSRS server inventory
. .\SSRS-Core-Functions.ps1
Connect-RsReportServer -ReportServerUri "http://localhost/ReportServer"
Get-RsFolderContent -RsFolder "/" -Recurse
```

## 🔧 Configuration Options

### Deployment Configuration (`deployment-config.json`)

| Section | Description |
|---------|-------------|
| `DataSources` | Default connection strings and settings for different environments |
| `Deployment` | Deployment behavior settings (overwrite, create folders, etc.) |
| `Folders` | Target folder structure on SSRS server |
| `Security` | Default security roles and permissions |
| `Environments` | Environment-specific server URLs and settings |

### Command Line Parameters

| Parameter | Description | Required |
|-----------|-------------|----------|
| `ReportServerUrl` | SSRS Report Server URL | Yes |
| `TargetFolder` | Target folder on SSRS server | Yes |
| `Environment` | Deployment environment (Dev/Test/Prod) | No |
| `ConfigFile` | Path to configuration file | No |
| `Credential` | PowerShell credentials for SSRS connection | No |
| `Force` | Force deployment ignoring warnings | No |
| `WhatIf` | Test deployment without making changes | No |

## 📝 Logging

All deployment activities are logged to the `Logs/` folder with timestamps:
- **INFO**: General information messages
- **SUCCESS**: Successful operations (green)
- **WARNING**: Warning messages (yellow)
- **ERROR**: Error messages (red)

Log files are named: `SSRS_Deployment_YYYYMMDD_HHMMSS.log`

## 🛠 Advanced Usage

### Custom Data Source Creation

```powershell
# Create a custom data source programmatically
Deploy-SingleDataSource `
  -DataSourceName "CustomDB" `
  -ConnectionString "Data Source=server;Initial Catalog=DB;User ID=user;Password=pass" `
  -ReportServerUrl "http://localhost/ReportServer" `
  -Extension "SQL" `
  -CredentialRetrieval "Store" `
  -DatasourceCredentials (Get-Credential)
```

### Batch Deployment from Multiple Folders

```powershell
# Deploy different types from different locations
Deploy-FromFolder -SourceFolder "C:\Reports\Sales" -FileExtension "*.rdl" -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/Sales"
Deploy-FromFolder -SourceFolder "C:\Reports\Finance" -FileExtension "*.rdl" -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/Finance"
```

### Environment-Specific Deployment

```powershell
# Development
.\Deploy-SSRS.ps1 -ReportServerUrl "http://dev-server/ReportServer" -TargetFolder "/Dev-Reports" -Environment "Dev"

# Production
.\Deploy-SSRS.ps1 -ReportServerUrl "https://prod-server/ReportServer" -TargetFolder "/Prod-Reports" -Environment "Prod" -Credential (Get-Credential)
```

## 🔍 Troubleshooting

### Common Issues

1. **Connection Issues**
   - Verify SSRS URL is correct and accessible
   - Check credentials and permissions
   - Ensure SSRS service is running
   - Test with: `.\Setup-Package.ps1 -TestConnection -ReportServerUrl "your-server-url"`

2. **PowerShell Execution Policy**
   - Run: `Set-ExecutionPolicy -ExecutionPolicy RemoteSigned -Scope CurrentUser`
   - Or run: `PowerShell -ExecutionPolicy Bypass -File Deploy-SSRS.ps1`

3. **SSRS Web Service Access**
   - Ensure the ReportService2010.asmx endpoint is accessible
   - Check firewall settings and network connectivity
   - Verify SSRS is configured for web service access

3. **Permission Errors**
   - Use credentials with appropriate SSRS permissions
   - Ensure service account has necessary database access

### Debug Mode

Add `-Verbose` parameter for detailed output:
```powershell
.\Deploy-SSRS.ps1 -ReportServerUrl "http://localhost/ReportServer" -TargetFolder "/Reports" -Environment "Dev" -Verbose
```

## 📋 File Type Support

| File Type | Extension | Description |
|-----------|-----------|-------------|
| Reports | `.rdl` | SQL Server Report Definition files |
| Data Sources | `.rds` | Report Data Source files |
| Datasets | `.rsd` | Report Dataset files |
| Images | `.jpg`, `.png` | Image resources for reports |

## 🚀 Best Practices

1. **Test First**: Always use `-WhatIf` parameter to test deployments
2. **Environment Isolation**: Use separate target folders for different environments
3. **Version Control**: Keep your deployment package in source control
4. **Backup**: Backup existing SSRS content before major deployments
5. **Security**: Use secure credentials and avoid hardcoding passwords
6. **Logging**: Review deployment logs for any issues or warnings

## 🤝 Contributing

Feel free to enhance this deployment package:
- Add new features or improvements
- Report issues or bugs
- Submit pull requests
- Enhance documentation

## 📄 License

This project is based on Microsoft ReportingServicesTools which is licensed under the MIT License.

## 🙏 Acknowledgments

- Microsoft ReportingServicesTools team for the excellent PowerShell module
- SQL Server Reporting Services community for best practices and feedback

---

**Happy Deploying! 🚀**
