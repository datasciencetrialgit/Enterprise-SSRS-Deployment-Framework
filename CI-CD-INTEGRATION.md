# CI/CD Integration Guide

This guide shows how to integrate the Enterprise-SSRS-Deployment-Framework with various CI/CD platforms using the `-User` and `-Password` parameters for automated authentication.

## 🎯 Overview

The Enterprise-SSRS-Deployment-Framework supports automated deployments through:
- **Username/Password Authentication**: Perfect for service accounts in CI/CD
- **Non-Interactive Mode**: No prompts or user input required
- **Environment-Based Configuration**: Different settings per environment
- **Comprehensive Logging**: Full audit trail of deployment activities

## 🔧 Authentication Methods Priority

The script uses the following authentication priority:

1. **User + Password Parameters** (Recommended for CI/CD)
2. **Credential Parameter** (PSCredential object)
3. **Current User Authentication** (Default for interactive use)
4. **Prompted Credentials** (Interactive mode only)

## 🚀 Platform Examples

### GitHub Actions

#### Basic Workflow
```yaml
name: Deploy SSRS Reports
on:
  push:
    branches: [ main ]

jobs:
  deploy:
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4
    - name: Deploy Reports
      run: |
        .\Deploy-SSRS.ps1 `
          -Environment "Prod" `
          -User "${{ secrets.SSRS_USERNAME }}" `
          -Password "${{ secrets.SSRS_PASSWORD }}"
      shell: powershell
```

#### Multi-Environment Workflow
```yaml
name: Multi-Environment SSRS Deployment
on:
  push:
    branches: [ main, develop ]

jobs:
  deploy-dev:
    if: github.ref == 'refs/heads/develop'
    runs-on: windows-latest
    steps:
    - uses: actions/checkout@v4
    - name: Deploy to Dev
      run: |
        .\Deploy-SSRS.ps1 `
          -Environment "Dev" `
          -User "${{ secrets.DEV_SSRS_USERNAME }}" `
          -Password "${{ secrets.DEV_SSRS_PASSWORD }}" `
          -Force
      shell: powershell

  deploy-prod:
    if: github.ref == 'refs/heads/main'
    runs-on: windows-latest
    environment: production
    steps:
    - uses: actions/checkout@v4
    - name: Deploy to Production
      run: |
        .\Deploy-SSRS.ps1 `
          -Environment "Prod" `
          -User "${{ secrets.PROD_SSRS_USERNAME }}" `
          -Password "${{ secrets.PROD_SSRS_PASSWORD }}" `
          -Force
      shell: powershell
```

### Azure DevOps

#### Basic Pipeline
```yaml
trigger:
- main

pool:
  vmImage: 'windows-latest'

variables:
- group: SSRS-Variables

steps:
- task: PowerShell@2
  displayName: 'Deploy SSRS Reports'
  inputs:
    targetType: 'inline'
    script: |
      .\Deploy-SSRS.ps1 `
        -Environment "$(Environment)" `
        -User "$(SSRS_USERNAME)" `
        -Password "$(SSRS_PASSWORD)" `
        -Force
```

#### Multi-Stage Pipeline
```yaml
stages:
- stage: Deploy_Dev
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/develop')
  jobs:
  - job: DeployToDev
    pool:
      vmImage: 'windows-latest'
    steps:
    - task: PowerShell@2
      inputs:
        targetType: 'inline'
        script: |
          .\Deploy-SSRS.ps1 `
            -ReportServerUrl "$(DEV_SSRS_SERVER_URL)" `
            -TargetFolder "/DevReports" `
            -Environment "Dev" `
            -User "$(DEV_SSRS_USERNAME)" `
            -Password "$(DEV_SSRS_PASSWORD)"

- stage: Deploy_Prod
  condition: eq(variables['Build.SourceBranch'], 'refs/heads/main')
  jobs:
  - deployment: DeployToProd
    environment: 'Production'
    pool:
      vmImage: 'windows-latest'
    strategy:
      runOnce:
        deploy:
          steps:
          - task: PowerShell@2
            inputs:
              targetType: 'inline'
              script: |
                .\Deploy-SSRS.ps1 `
                  -ReportServerUrl "$(PROD_SSRS_SERVER_URL)" `
                  -TargetFolder "/ProdReports" `
                  -Environment "Prod" `
                  -User "$(PROD_SSRS_USERNAME)" `
                  -Password "$(PROD_SSRS_PASSWORD)"
```

### Jenkins

#### Declarative Pipeline
```groovy
pipeline {
    agent {
        label 'windows'
    }
    
    environment {
        SSRS_SERVER_URL = credentials('ssrs-server-url')
        SSRS_USERNAME = credentials('ssrs-username')
        SSRS_PASSWORD = credentials('ssrs-password')
    }
    
    stages {
        stage('Deploy SSRS') {
            steps {
                powershell '''
                    .\\Deploy-SSRS.ps1 `
                        -ReportServerUrl $env:SSRS_SERVER_URL `
                        -TargetFolder "/Reports" `
                        -Environment "Prod" `
                        -User $env:SSRS_USERNAME `
                        -Password $env:SSRS_PASSWORD `
                        -Force
                '''
            }
        }
    }
    
    post {
        always {
            archiveArtifacts artifacts: 'Logs/*.log', fingerprint: true
        }
    }
}
```

### GitLab CI/CD

#### Basic Pipeline
```yaml
stages:
  - deploy

deploy-ssrs:
  stage: deploy
  only:
    - main
  script:
    - |
      .\Deploy-SSRS.ps1 `
        -ReportServerUrl "$SSRS_SERVER_URL" `
        -TargetFolder "/Reports" `
        -Environment "Prod" `
        -User "$SSRS_USERNAME" `
        -Password "$SSRS_PASSWORD" `
        -Force
  tags:
    - windows
  artifacts:
    paths:
      - Logs/
    expire_in: 30 days
```

## 🔒 Security Best Practices

### 1. Service Account Setup
```powershell
# Create dedicated service account for SSRS deployment
# Grant minimum required permissions:
# - SSRS: Content Manager role on target folders
# - Database: db_datareader on source databases (for data sources)
```

### 2. Secret Management

#### GitHub Actions Secrets
- Repository Settings → Secrets and Variables → Actions
- Use environment-specific secrets:
  - `DEV_SSRS_USERNAME`, `DEV_SSRS_PASSWORD`
  - `PROD_SSRS_USERNAME`, `PROD_SSRS_PASSWORD`

#### Azure DevOps Variable Groups
```yaml
variables:
- group: SSRS-Dev-Variables    # Contains dev credentials
- group: SSRS-Prod-Variables   # Contains prod credentials
```

#### Jenkins Credentials
- Manage Jenkins → Credentials
- Add Username with Password credentials
- Reference in pipeline: `credentials('credential-id')`

### 3. Environment Protection

#### GitHub Environments
```yaml
environment: production  # Requires approval for prod deployments
```

#### Azure DevOps Environments
- Create environments with approval gates
- Restrict deployment to specific branches

### 4. Audit and Monitoring

#### Enable Logging
```powershell
# Logs are automatically created in Logs/ directory
# Upload logs as CI/CD artifacts for audit trail
```

#### Monitor Deployments
```powershell
# Add deployment notifications
# Monitor SSRS server logs
# Set up alerts for failed deployments
```

## 📋 Parameter Reference

### Required for CI/CD
| Parameter | Description | Example |
|-----------|-------------|---------|
| `Environment` | Environment name | `Dev`, `Test`, `Prod` |
| `User` | Service account username | `domain\svc-ssrs` |
| `Password` | Service account password | `secure-password` |

### Optional Parameters (Override Config)
| Parameter | Description | Example |
|-----------|-------------|---------|
| `ReportServerUrl` | Override SSRS server URL | `http://server/ReportServer` |
| `TargetFolder` | Override deployment folder | `/Reports` |
| `ConfigFile` | Configuration file path | `Deploy\Config\deployment-config.json` |
| `Force` | Skip confirmations | `$false` |
| `WhatIf` | Test mode only | `$false` |

**Note**: When `ReportServerUrl` and `TargetFolder` are not specified, they are automatically read from the configuration file based on the `Environment` parameter.

## 🔍 Troubleshooting

### Common Issues

#### Authentication Failures
```powershell
# Test authentication separately
.\Deploy-SSRS.ps1 -ReportServerUrl "http://server/ReportServer" -User "domain\user" -Password "pass" -WhatIf
```

#### Network Connectivity
```powershell
# Test network access to SSRS server
Test-NetConnection -ComputerName "ssrs-server" -Port 80
```

#### Permission Issues
```powershell
# Verify service account has proper SSRS permissions
# Check database access for data source connections
```

### Debug Mode
```powershell
# Enable verbose logging
.\Deploy-SSRS.ps1 -User "domain\user" -Password "pass" -Verbose
```

## 📖 Examples Repository

Check the `Examples/` directory for:
- Complete GitHub Actions workflows
- Azure DevOps pipeline templates
- Jenkins pipeline examples
- PowerShell deployment scripts

## 🤝 Contributing

To improve CI/CD integration:
1. Test with your platform
2. Submit issues for platform-specific problems
3. Share working pipeline examples
4. Contribute documentation improvements

---

**Ready for automated SSRS deployments! 🚀**
