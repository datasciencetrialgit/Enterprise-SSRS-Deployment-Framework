# SSRS Deployment PowerShell Module
# Module manifest for the SSRS-Deployment-Package

@{
    # Script module or binary module file associated with this manifest
    RootModule = 'SSRS-Deployment.psm1'
    
    # Version number of this module
    ModuleVersion = '1.0.0'
    
    # Supported PSEditions
    CompatiblePSEditions = @('Desktop', 'Core')
    
    # ID used to uniquely identify this module
    GUID = 'a1b2c3d4-e5f6-7890-abcd-ef1234567890'
    
    # Author of this module
    Author = 'SSRS Deployment Team'
    
    # Company or vendor of this module
    CompanyName = 'Data Solutions'
    
    # Copyright statement for this module
    Copyright = '(c) 2025 Data Solutions. All rights reserved.'
    
    # Description of the functionality provided by this module
    Description = 'PowerShell module for deploying SQL Server Reporting Services (SSRS) reports, data sources, and datasets with comprehensive authentication support.'
    
    # Minimum version of the PowerShell engine required by this module
    PowerShellVersion = '5.1'
    
    # Name of the PowerShell host required by this module
    # PowerShellHostName = ''
    
    # Minimum version of the PowerShell host required by this module
    # PowerShellHostVersion = ''
    
    # Minimum version of Microsoft .NET Framework required by this module
    DotNetFrameworkVersion = '4.5'
    
    # Minimum version of the common language runtime (CLR) required by this module
    # ClrVersion = ''
    
    # Processor architecture (None, X86, Amd64) required by this module
    # ProcessorArchitecture = ''
    
    # Modules that must be imported into the global environment prior to importing this module
    # RequiredModules = @()
    
    # Assemblies that must be loaded prior to importing this module
    # RequiredAssemblies = @()
    
    # Script files (.ps1) that are run in the caller's environment prior to importing this module
    # ScriptsToProcess = @()
    
    # Type files (.ps1xml) to be loaded when importing this module
    # TypesToProcess = @()
    
    # Format files (.ps1xml) to be loaded when importing this module
    # FormatsToProcess = @()
    
    # Modules to import as nested modules of the module specified in RootModule/ModuleToProcess
    # NestedModules = @()
    
    # Functions to export from this module
    FunctionsToExport = @(
        'Invoke-SSRSDeployment',
        'Deploy-SSRSReports',
        'Deploy-SSRSDataSources', 
        'Deploy-SSRSDataSets',
        'Connect-SSRSServer',
        'Test-SSRSConnection',
        'New-SSRSFolder',
        'Get-SSRSFolderContent'
    )
    
    # Cmdlets to export from this module
    CmdletsToExport = @()
    
    # Variables to export from this module
    VariablesToExport = @()
    
    # Aliases to export from this module
    AliasesToExport = @(
        'Deploy-SSRS',
        'Deploy-Reports',
        'Connect-SSRS',
        'Test-SSRS'
    )
    
    # DSC resources to export from this module
    # DscResourcesToExport = @()
    
    # List of all modules packaged with this module
    # ModuleList = @()
    
    # List of all files packaged with this module
    FileList = @(
        'SSRS-Deployment.psm1',
        'SSRS-Deployment.psd1',
        'Deploy-SSRS.ps1',
        'Config\deployment-config.json',
        'README.md',
        'AUTHENTICATION.md',
        'Examples.ps1',
        'Secure-Authentication-Examples.ps1'
    )
    
    # Private data to pass to the module specified in RootModule/ModuleToProcess
    PrivateData = @{
        PSData = @{
            # Tags applied to this module
            Tags = @('SSRS', 'Reporting', 'Deployment', 'SQL', 'PowerShell', 'Automation')
            
            # A URL to the license for this module
            # LicenseUri = ''
            
            # A URL to the main website for this project
            # ProjectUri = ''
            
            # A URL to an icon representing this module
            # IconUri = ''
            
            # ReleaseNotes of this module
            ReleaseNotes = @'
Version 1.0.0:
- Initial release of SSRS Deployment PowerShell Module
- Support for deploying reports, data sources, and datasets
- Multiple authentication methods including User/Password parameters
- Comprehensive logging and error handling
- Flexible folder structure support
- Security features with password masking
- WhatIf support for testing deployments
'@
            
            # Prerelease string of this module
            # Prerelease = ''
            
            # Flag to indicate whether the module requires explicit user acceptance
            # RequireLicenseAcceptance = $false
            
            # External dependent modules of this module
            # ExternalModuleDependencies = @()
        }
    }
    
    # HelpInfo URI of this module
    # HelpInfoURI = ''
    
    # Default prefix for commands exported from this module
    # DefaultCommandPrefix = ''
}
