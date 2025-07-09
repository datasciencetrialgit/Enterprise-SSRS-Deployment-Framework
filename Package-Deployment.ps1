# ======================================================================
# SSRS Deployment Package Builder
# Creates a packaged deployment with executables and batch files
# ======================================================================

<#
.SYNOPSIS
    Packages the SSRS deployment scripts into a distributable package.

.DESCRIPTION
    This script creates a complete deployment package that includes:
    - Compiled PowerShell executables for all scripts
    - Deploy folder with configuration and content
    - Batch file for easy deployment execution
    - Documentation and examples

.PARAMETER OutputPath
    The path where the package will be created. Default is ".\Package"

.PARAMETER Version
    The version number for the package. Default is current date.

.EXAMPLE
    .\Package-Deployment.ps1
    Creates a package in the default "Package" folder.

.EXAMPLE
    .\Package-Deployment.ps1 -OutputPath "C:\Deploy\SSRSPackage" -Version "1.0.0"
    Creates a package with specific path and version.
#>

param(
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\Package",
    
    [Parameter(Mandatory = $false)]
    [string]$Version = (Get-Date -Format "yyyy.MM.dd")
)

# ======================================================================
# CONFIGURATION
# ======================================================================

$ScriptPath = Split-Path -Parent $MyInvocation.MyCommand.Path
$PackageName = "SSRS-Deployment-Package-v$Version"
$FullOutputPath = Join-Path $OutputPath $PackageName

# Scripts to compile to executables
$ScriptsToCompile = @(
    @{
        Script = "Deploy-SSRS.ps1"
        ExeName = "Deploy-SSRS.exe"
        Description = "Main SSRS Deployment Tool"
    },
    @{
        Script = "Setup-Package.ps1"
        ExeName = "Setup-Package.exe"
        Description = "Package Setup and Validation"
    },
    @{
        Script = "Validate-Setup.ps1"
        ExeName = "Validate-Setup.exe"
        Description = "Deployment Validation Tool"
    }
)

# Folders to copy
$FoldersToCopy = @(
    "Deploy",
    "Logs"
)

# Files to copy
$FilesToCopy = @(
    "README.md",
    "AUTHENTICATION.md",
    "SECURITY-BEST-PRACTICES.md",
    "INSTALLATION-COMPLETE.md",
    "Examples.ps1",
    "Secure-Authentication-Examples.ps1",
    "SSRS-Core-Functions.ps1",
    "SSRS-Helper-Functions.ps1"
)

# ======================================================================
# FUNCTIONS
# ======================================================================

function Write-PackageLog {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "HH:mm:ss"
    $ColorMap = @{
        "INFO" = "Cyan"
        "WARNING" = "Yellow"
        "ERROR" = "Red"
        "SUCCESS" = "Green"
    }
    
    Write-Host "[$TimeStamp] [$Level] $Message" -ForegroundColor $ColorMap[$Level]
}

function Test-PS2EXE {
    <#
    .SYNOPSIS
        Checks if PS2EXE module is available for creating executables.
    #>
    try {
        $PS2EXE = Get-Module -ListAvailable -Name "PS2EXE"
        if ($PS2EXE) {
            Write-PackageLog "PS2EXE module found (Version: $($PS2EXE.Version))" -Level "SUCCESS"
            return $true
        } else {
            Write-PackageLog "PS2EXE module not found. Installing..." -Level "WARNING"
            Install-Module -Name "PS2EXE" -Force -Scope CurrentUser
            Write-PackageLog "PS2EXE module installed successfully" -Level "SUCCESS"
            return $true
        }
    }
    catch {
        Write-PackageLog "Failed to install PS2EXE: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function New-ExecutableFromScript {
    <#
    .SYNOPSIS
        Creates an executable from a PowerShell script using PS2EXE.
    #>
    param(
        [string]$ScriptPath,
        [string]$ExePath,
        [string]$Title,
        [string]$Description
    )
    
    try {
        Write-PackageLog "Creating executable: $ExePath" -Level "INFO"
        
        # Import PS2EXE module
        Import-Module PS2EXE -Force
        
        # Create executable with enhanced parameters
        Invoke-ps2exe `
            -inputFile $ScriptPath `
            -outputFile $ExePath `
            -title $Title `
            -description $Description `
            -company "SSRS Deployment Package" `
            -version $Version `
            -copyright "Copyright (c) $(Get-Date -Format 'yyyy')" `
            -iconFile $null `
            -noConsole:$false `
            -noOutput:$false `
            -noError:$false `
            -requireAdmin:$false `
            -supportOS:$true `
            -virtualize:$false `
            -longPaths:$true
        
        if (Test-Path $ExePath) {
            Write-PackageLog "Successfully created: $ExePath" -Level "SUCCESS"
            return $true
        } else {
            Write-PackageLog "Failed to create executable: $ExePath" -Level "ERROR"
            return $false
        }
    }
    catch {
        Write-PackageLog "Error creating executable: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function New-DeploymentBatch {
    <#
    .SYNOPSIS
        Creates a batch file for easy deployment execution.
    #>
    param(
        [string]$BatchPath
    )
    
    $BatchContent = @"
@echo off
title SSRS Deployment Package

echo ======================================================================
echo SSRS Deployment Package v$Version
echo ======================================================================
echo.

REM Get credentials from user
set /p USERNAME="Enter Username: "
set /p PASSWORD="Enter Password: " 

REM Get environment
set /p ENVIRONMENT="Enter Environment (Dev/Test/Prod): "

REM Get target folder (optional)
set /p TARGETFOLDER="Enter Target Folder (or press Enter for root): "

echo.
echo ======================================================================
echo Starting SSRS Deployment...
echo ======================================================================
echo.

REM Build the command
set DEPLOY_CMD=Deploy-SSRS.exe -Environment "%ENVIRONMENT%" -User "%USERNAME%" -Pwd "%PASSWORD%"

REM Add target folder if specified
if not "%TARGETFOLDER%"=="" (
    set DEPLOY_CMD=%DEPLOY_CMD% -TargetFolder "%TARGETFOLDER%"
)

REM Execute deployment
%DEPLOY_CMD%

echo.
echo ======================================================================
echo Deployment completed. Press any key to exit...
echo ======================================================================
pause >nul
"@

    try {
        Set-Content -Path $BatchPath -Value $BatchContent -Encoding ASCII
        Write-PackageLog "Created deployment batch file: $BatchPath" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-PackageLog "Failed to create batch file: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function New-SecureBatch {
    <#
    .SYNOPSIS
        Creates a more secure batch file that prompts for credentials without displaying password.
    #>
    param(
        [string]$BatchPath
    )
    
    $BatchContent = @"
@echo off
setlocal EnableDelayedExpansion
title SSRS Deployment Package - Secure Mode

echo ======================================================================
echo SSRS Deployment Package v$Version - Secure Deployment
echo ======================================================================
echo.
echo This script will prompt for credentials securely.
echo The password will not be displayed on screen.
echo.

REM Get username
set /p USERNAME="Enter Username: "

REM Get environment
set /p ENVIRONMENT="Enter Environment (Dev/Test/Prod): "

REM Get target folder (optional)
set /p TARGETFOLDER="Enter Target Folder (or press Enter for root): "

echo.
echo ======================================================================
echo Starting SSRS Deployment...
echo ======================================================================
echo.

REM Use PowerShell to get secure password and execute deployment
powershell.exe -Command "& { `$cred = Get-Credential -UserName '%USERNAME%' -Message 'Enter SSRS Credentials'; if (`$cred) { if ('%TARGETFOLDER%' -eq '') { .\Deploy-SSRS.exe -Environment '%ENVIRONMENT%' -User `$cred.UserName -Pwd ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR(`$cred.Password))) } else { .\Deploy-SSRS.exe -Environment '%ENVIRONMENT%' -User `$cred.UserName -Pwd ([Runtime.InteropServices.Marshal]::PtrToStringAuto([Runtime.InteropServices.Marshal]::SecureStringToBSTR(`$cred.Password))) -TargetFolder '%TARGETFOLDER%' } } else { Write-Host 'Deployment cancelled.' } }"

echo.
echo ======================================================================
echo Deployment completed. Press any key to exit...
echo ======================================================================
pause >nul
"@

    try {
        Set-Content -Path $BatchPath -Value $BatchContent -Encoding ASCII
        Write-PackageLog "Created secure deployment batch file: $BatchPath" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-PackageLog "Failed to create secure batch file: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function New-ReadmeFile {
    <#
    .SYNOPSIS
        Creates a README file for the package.
    #>
    param(
        [string]$ReadmePath
    )
    
    $ReadmeContent = @"
# SSRS Deployment Package v$Version

## Overview
This package contains everything needed to deploy SSRS reports, data sources, and datasets to SQL Server Reporting Services.

## Contents
- **Deploy-SSRS.exe**: Main deployment executable
- **Setup-Package.exe**: Package setup and validation
- **Validate-Setup.exe**: Deployment validation tool
- **Deploy/**: Folder containing configuration and deployment assets
- **Deploy-Simple.bat**: Simple batch file for deployment
- **Deploy-Secure.bat**: Secure batch file that prompts for credentials safely
- **Documentation**: Complete documentation and examples

## Quick Start

### Option 1: Using Secure Batch File (Recommended)
1. Double-click `Deploy-Secure.bat`
2. Enter your credentials when prompted
3. Select environment (Dev/Test/Prod)
4. Optionally specify a target folder

### Option 2: Using Simple Batch File
1. Double-click `Deploy-Simple.bat`
2. Enter username, password, and environment
3. Wait for deployment to complete

### Option 3: Using Command Line
```cmd
Deploy-SSRS.exe -Environment "Dev" -User "your.email@domain.com" -Pwd "your.password"
```

## Configuration
Edit `Deploy\Config\deployment-config.json` to customize:
- Server URLs for different environments
- Connection strings
- Security settings
- Deployment options

## Security
- Passwords are never stored in logs or displayed in console
- Use the secure batch file for production deployments
- See SECURITY-BEST-PRACTICES.md for detailed security guidance

## Support
- See README.md for detailed documentation
- Check AUTHENTICATION.md for authentication options
- Review Examples.ps1 for usage examples

Generated on: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
"@

    try {
        Set-Content -Path $ReadmePath -Value $ReadmeContent -Encoding UTF8
        Write-PackageLog "Created package README: $ReadmePath" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-PackageLog "Failed to create README: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

# ======================================================================
# MAIN EXECUTION
# ======================================================================

Write-PackageLog "======================================================================" -Level "INFO"
Write-PackageLog "SSRS Deployment Package Builder v$Version" -Level "INFO"
Write-PackageLog "======================================================================" -Level "INFO"

# Create output directory
Write-PackageLog "Creating package directory: $FullOutputPath" -Level "INFO"
if (Test-Path $FullOutputPath) {
    Remove-Item $FullOutputPath -Recurse -Force
}
New-Item -ItemType Directory -Path $FullOutputPath -Force | Out-Null

# Check for PS2EXE
Write-PackageLog "Checking for PS2EXE module..." -Level "INFO"
if (-not (Test-PS2EXE)) {
    Write-PackageLog "Cannot proceed without PS2EXE module. Package creation failed." -Level "ERROR"
    exit 1
}

# Copy folders
Write-PackageLog "Copying deployment folders..." -Level "INFO"
foreach ($Folder in $FoldersToCopy) {
    $SourcePath = Join-Path $ScriptPath $Folder
    $DestPath = Join-Path $FullOutputPath $Folder
    
    if (Test-Path $SourcePath) {
        Copy-Item -Path $SourcePath -Destination $DestPath -Recurse -Force
        Write-PackageLog "Copied folder: $Folder" -Level "SUCCESS"
    } else {
        Write-PackageLog "Folder not found: $Folder" -Level "WARNING"
    }
}

# Copy files
Write-PackageLog "Copying documentation and support files..." -Level "INFO"
foreach ($File in $FilesToCopy) {
    $SourcePath = Join-Path $ScriptPath $File
    $DestPath = Join-Path $FullOutputPath $File
    
    if (Test-Path $SourcePath) {
        Copy-Item -Path $SourcePath -Destination $DestPath -Force
        Write-PackageLog "Copied file: $File" -Level "SUCCESS"
    } else {
        Write-PackageLog "File not found: $File" -Level "WARNING"
    }
}

# Create executables
Write-PackageLog "Creating executable files..." -Level "INFO"
$ExecutableCount = 0
foreach ($ScriptInfo in $ScriptsToCompile) {
    $SourceScript = Join-Path $ScriptPath $ScriptInfo.Script
    $DestExe = Join-Path $FullOutputPath $ScriptInfo.ExeName
    
    if (Test-Path $SourceScript) {
        if (New-ExecutableFromScript -ScriptPath $SourceScript -ExePath $DestExe -Title $ScriptInfo.Description -Description $ScriptInfo.Description) {
            $ExecutableCount++
        }
    } else {
        Write-PackageLog "Script not found: $($ScriptInfo.Script)" -Level "WARNING"
    }
}

# Create batch files
Write-PackageLog "Creating deployment batch files..." -Level "INFO"
$SimpleBatchPath = Join-Path $FullOutputPath "Deploy-Simple.bat"
$SecureBatchPath = Join-Path $FullOutputPath "Deploy-Secure.bat"

New-DeploymentBatch -BatchPath $SimpleBatchPath
New-SecureBatch -BatchPath $SecureBatchPath

# Create package README
Write-PackageLog "Creating package documentation..." -Level "INFO"
$PackageReadmePath = Join-Path $FullOutputPath "PACKAGE-README.txt"
New-ReadmeFile -ReadmePath $PackageReadmePath

# Package summary
Write-PackageLog "======================================================================" -Level "INFO"
Write-PackageLog "PACKAGE CREATION COMPLETED" -Level "SUCCESS"
Write-PackageLog "======================================================================" -Level "INFO"
Write-PackageLog "Package Location: $FullOutputPath" -Level "INFO"
Write-PackageLog "Executables Created: $ExecutableCount" -Level "INFO"
Write-PackageLog "Package Size: $((Get-ChildItem $FullOutputPath -Recurse | Measure-Object -Property Length -Sum).Sum / 1MB) MB" -Level "INFO"
Write-PackageLog "======================================================================" -Level "INFO"

# Open package folder
if (Test-Path $FullOutputPath) {
    Write-PackageLog "Opening package folder..." -Level "INFO"
    Start-Process "explorer.exe" -ArgumentList $FullOutputPath
}

Write-PackageLog "Package creation completed successfully!" -Level "SUCCESS"
