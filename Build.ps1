# Build Script for SSRS-Deployment PowerShell Module
# This script helps build, test, and package the PowerShell module

[CmdletBinding()]
param(
    [Parameter(Mandatory = $false)]
    [ValidateSet('Clean', 'Build', 'Test', 'Package', 'Install', 'Uninstall', 'All')]
    [string]$Task = 'Build',
    
    [Parameter(Mandatory = $false)]
    [string]$OutputPath = ".\Output",
    
    [Parameter(Mandatory = $false)]
    [string]$ModuleName = "SSRS-Deployment"
)

# Module information
$ModuleRoot = $PSScriptRoot
$ModuleManifest = Join-Path $ModuleRoot "$ModuleName.psd1"
$ModuleFile = Join-Path $ModuleRoot "$ModuleName.psm1"

Write-Host "=== SSRS-Deployment Module Build Script ===" -ForegroundColor Cyan
Write-Host "Task: $Task" -ForegroundColor Yellow
Write-Host "Module Root: $ModuleRoot" -ForegroundColor Gray
Write-Host "Output Path: $OutputPath" -ForegroundColor Gray
Write-Host ""

function Invoke-Clean {
    Write-Host "🧹 Cleaning output directory..." -ForegroundColor Yellow
    if (Test-Path $OutputPath) {
        Remove-Item $OutputPath -Recurse -Force
        Write-Host "✅ Cleaned: $OutputPath" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Output directory doesn't exist: $OutputPath" -ForegroundColor Gray
    }
}

function Invoke-Build {
    Write-Host "🔨 Building module..." -ForegroundColor Yellow
    
    # Create output directory
    if (!(Test-Path $OutputPath)) {
        New-Item -ItemType Directory -Path $OutputPath -Force | Out-Null
    }
    
    $ModuleOutputPath = Join-Path $OutputPath $ModuleName
    if (!(Test-Path $ModuleOutputPath)) {
        New-Item -ItemType Directory -Path $ModuleOutputPath -Force | Out-Null
    }
    
    # Copy module files
    $FilesToCopy = @(
        "$ModuleName.psd1",
        "$ModuleName.psm1", 
        "Deploy-SSRS.ps1",
        "SSRS-Core-Functions.ps1",
        "SSRS-Helper-Functions.ps1",
        "README.md",
        "AUTHENTICATION.md",
        "Examples.ps1",
        "Secure-Authentication-Examples.ps1",
        "Authentication-Examples.ps1"
    )
    
    foreach ($File in $FilesToCopy) {
        $SourceFile = Join-Path $ModuleRoot $File
        if (Test-Path $SourceFile) {
            Copy-Item $SourceFile -Destination $ModuleOutputPath -Force
            Write-Host "  📄 Copied: $File" -ForegroundColor Green
        } else {
            Write-Host "  ⚠️  File not found: $File" -ForegroundColor Yellow
        }
    }
    
    # Copy Config directory
    $ConfigSource = Join-Path $ModuleRoot "Config"
    if (Test-Path $ConfigSource) {
        Copy-Item $ConfigSource -Destination $ModuleOutputPath -Recurse -Force
        Write-Host "  📁 Copied: Config directory" -ForegroundColor Green
    }
    
    # Copy sample folders
    $FoldersToCreate = @("RDL-Files", "DataSources", "DataSets", "Logs")
    foreach ($Folder in $FoldersToCreate) {
        $FolderPath = Join-Path $ModuleOutputPath $Folder
        if (!(Test-Path $FolderPath)) {
            New-Item -ItemType Directory -Path $FolderPath -Force | Out-Null
            Write-Host "  📁 Created: $Folder directory" -ForegroundColor Green
        }
    }
    
    # Copy sample RDL files if they exist
    $RDLSource = Join-Path $ModuleRoot "RDL-Files"
    if (Test-Path $RDLSource) {
        Copy-Item "$RDLSource\*" -Destination (Join-Path $ModuleOutputPath "RDL-Files") -Force -ErrorAction SilentlyContinue
    }
    
    Write-Host "✅ Build completed: $ModuleOutputPath" -ForegroundColor Green
}

function Invoke-Test {
    Write-Host "🧪 Testing module..." -ForegroundColor Yellow
    
    # Test module manifest
    try {
        $Manifest = Test-ModuleManifest -Path $ModuleManifest -ErrorAction Stop
        Write-Host "✅ Module manifest is valid" -ForegroundColor Green
        Write-Host "  📋 Module: $($Manifest.Name) v$($Manifest.Version)" -ForegroundColor Gray
    }
    catch {
        Write-Host "❌ Module manifest test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test module syntax
    try {
        $null = Get-Content $ModuleFile -Raw | Invoke-Expression
        Write-Host "✅ Module syntax is valid" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Module syntax test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    # Test core script syntax
    $DeployScript = Join-Path $ModuleRoot "Deploy-SSRS.ps1"
    try {
        $null = Get-Content $DeployScript -Raw
        Write-Host "✅ Deploy script syntax is valid" -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Deploy script syntax test failed: $($_.Exception.Message)" -ForegroundColor Red
        return $false
    }
    
    return $true
}

function Invoke-Package {
    Write-Host "📦 Packaging module..." -ForegroundColor Yellow
    
    if (!(Test-Path $OutputPath)) {
        Write-Host "❌ Build output not found. Run 'Build' first." -ForegroundColor Red
        return
    }
    
    $PackagePath = Join-Path $OutputPath "$ModuleName.zip"
    $ModuleOutputPath = Join-Path $OutputPath $ModuleName
    
    if (Test-Path $PackagePath) {
        Remove-Item $PackagePath -Force
    }
    
    # Create zip package
    Add-Type -AssemblyName System.IO.Compression.FileSystem
    [System.IO.Compression.ZipFile]::CreateFromDirectory($ModuleOutputPath, $PackagePath)
    
    Write-Host "✅ Package created: $PackagePath" -ForegroundColor Green
}

function Invoke-Install {
    Write-Host "📥 Installing module..." -ForegroundColor Yellow
    
    $ModuleOutputPath = Join-Path $OutputPath $ModuleName
    if (!(Test-Path $ModuleOutputPath)) {
        Write-Host "❌ Built module not found. Run 'Build' first." -ForegroundColor Red
        return
    }
    
    # Get user module path
    $UserModulePath = $env:PSModulePath.Split(';')[0]
    $InstallPath = Join-Path $UserModulePath $ModuleName
    
    # Remove existing module if it exists
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
        Write-Host "  🗑️  Removed existing module" -ForegroundColor Yellow
    }
    
    # Copy module to install location
    Copy-Item $ModuleOutputPath -Destination $UserModulePath -Recurse -Force
    Write-Host "✅ Module installed to: $InstallPath" -ForegroundColor Green
    
    # Test import
    try {
        Import-Module $ModuleName -Force
        Write-Host "✅ Module imported successfully" -ForegroundColor Green
        Get-Module $ModuleName | Format-Table Name, Version, ModuleType, ExportedCommands
    }
    catch {
        Write-Host "❌ Module import failed: $($_.Exception.Message)" -ForegroundColor Red
    }
}

function Invoke-Uninstall {
    Write-Host "📤 Uninstalling module..." -ForegroundColor Yellow
    
    # Remove module from session
    Remove-Module $ModuleName -Force -ErrorAction SilentlyContinue
    
    # Get user module path
    $UserModulePath = $env:PSModulePath.Split(';')[0]
    $InstallPath = Join-Path $UserModulePath $ModuleName
    
    if (Test-Path $InstallPath) {
        Remove-Item $InstallPath -Recurse -Force
        Write-Host "✅ Module uninstalled from: $InstallPath" -ForegroundColor Green
    } else {
        Write-Host "ℹ️  Module not found in: $InstallPath" -ForegroundColor Gray
    }
}

# Execute the requested task
switch ($Task) {
    'Clean' { Invoke-Clean }
    'Build' { Invoke-Build }
    'Test' { Invoke-Test }
    'Package' { Invoke-Package }
    'Install' { Invoke-Install }
    'Uninstall' { Invoke-Uninstall }
    'All' {
        Invoke-Clean
        Invoke-Build
        $TestResult = Invoke-Test
        if ($TestResult) {
            Invoke-Package
            Invoke-Install
        } else {
            Write-Host "❌ Build failed due to test failures" -ForegroundColor Red
        }
    }
}

Write-Host ""
Write-Host "🎉 Task '$Task' completed!" -ForegroundColor Green
