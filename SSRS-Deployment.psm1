# SSRS-Deployment PowerShell Module
# Main module file that exports functions and sets up the module environment

# Get the directory where this module is located
$ModuleRoot = Split-Path -Path $MyInvocation.MyCommand.Path -Parent

# Import the core SSRS functions
. (Join-Path $ModuleRoot "SSRS-Core-Functions.ps1")

# Set module-level variables
$Script:ModuleRoot = $ModuleRoot
$Script:DefaultConfigPath = Join-Path $ModuleRoot "Deploy\Config\deployment-config.json"

#region Main Deployment Functions

<#
.SYNOPSIS
    Deploy SSRS reports, data sources, and datasets to a Report Server.

.DESCRIPTION
    This is the main deployment function that handles the complete SSRS deployment process
    including reports, data sources, and datasets with comprehensive authentication options.

.PARAMETER ReportServerUrl
    The URL of the SSRS Report Server (e.g., http://server/ReportServer).

.PARAMETER TargetFolder
    The target folder path in SSRS where items will be deployed.

.PARAMETER Environment
    The environment configuration to use (Dev, Test, Prod).

.PARAMETER ConfigFile
    Path to the deployment configuration file.

.PARAMETER Credential
    PSCredential object for authentication.

.PARAMETER User
    Username for authentication.

.PARAMETER Pwd
    Password for authentication.

.PARAMETER PromptForCredentials
    Switch to prompt for credentials interactively.

.PARAMETER Force
    Force overwrite of existing items.

.PARAMETER WhatIf
    Show what would be deployed without actually deploying.

.EXAMPLE
    Deploy-SSRS -Environment "Dev" -User "user@domain.com" -Pwd "password"

.EXAMPLE
    Deploy-SSRS -Environment "Prod" -PromptForCredentials

.EXAMPLE
    Deploy-SSRS -Environment "Test" -WhatIf
#>
function Invoke-SSRSDeployment {
    [CmdletBinding(SupportsShouldProcess)]
    param(
        [Parameter(Mandatory = $false)]
        [string]$ReportServerUrl,
        
        [Parameter(Mandatory = $false)]
        [string]$TargetFolder,
        
        [Parameter(Mandatory = $false)]
        [ValidateSet("Dev", "Test", "Prod")]
        [string]$Environment = "Dev",
        
        [Parameter(Mandatory = $false)]
        [string]$ConfigFile = $Script:DefaultConfigPath,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential,
        
        [Parameter(Mandatory = $false)]
        [string]$User,
        
        [Parameter(Mandatory = $false)]
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Backward compatibility - password is masked in logs')]
        [string]$Password,
        
        [Parameter(Mandatory = $false)]
        [switch]$PromptForCredentials,
        
        [Parameter(Mandatory = $false)]
        [switch]$Force,
        
        [Parameter(Mandatory = $false)]
        [switch]$WhatIf
    )
    
    # Build parameters for the main deployment script
    $DeployParams = @{
        Environment = $Environment
        ConfigFile = $ConfigFile
    }
    
    if ($ReportServerUrl) { $DeployParams.ReportServerUrl = $ReportServerUrl }
    if ($TargetFolder) { $DeployParams.TargetFolder = $TargetFolder }
    if ($Credential) { $DeployParams.Credential = $Credential }
    if ($User) { $DeployParams.User = $User }
    if ($Password) { $DeployParams.Password = $Password }
    if ($PromptForCredentials) { $DeployParams.PromptForCredentials = $true }
    if ($Force) { $DeployParams.Force = $true }
    if ($WhatIf) { $DeployParams.WhatIf = $true }
    
    # Check if we should process (WhatIf/Confirm support)
    if ($PSCmdlet.ShouldProcess("SSRS Server at $ReportServerUrl", "Deploy SSRS Reports and Data Sources")) {
        # Execute the main deployment script
        $DeployScript = Join-Path $Script:ModuleRoot "Deploy-SSRS.ps1"
        & $DeployScript @DeployParams
    }
}

<#
.SYNOPSIS
    Connect to an SSRS Report Server.

.DESCRIPTION
    Establishes a connection to an SSRS Report Server using the specified credentials.

.PARAMETER ReportServerUri
    The URL of the SSRS Report Server.

.PARAMETER Credential
    PSCredential object for authentication.

.EXAMPLE
    Connect-SSRSServer -ReportServerUri "http://server/ReportServer" -Credential $cred
#>
function Connect-SSRSServer {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ReportServerUri,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Connect-RsReportServer -ReportServerUri $ReportServerUri -Credential $Credential
}

<#
.SYNOPSIS
    Test connection to SSRS Report Server.

.DESCRIPTION
    Tests the connection to an SSRS Report Server.

.PARAMETER ServerUrl
    The URL of the SSRS Report Server.

.PARAMETER Credential
    PSCredential object for authentication.

.EXAMPLE
    Test-SSRSConnection -ServerUrl "http://server/ReportServer"
#>
function Test-SSRSConnection {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$ServerUrl,
        
        [Parameter(Mandatory = $false)]
        [System.Management.Automation.PSCredential]$Credential
    )
    
    try {
        Connect-RsReportServer -ReportServerUri $ServerUrl -Credential $Credential
        $Items = Get-RsFolderContent -RsFolder "/"
        Write-Output "Connection successful. Found $($Items.Count) items in root folder."
        return $true
    }
    catch {
        Write-Error "Connection failed: $($_.Exception.Message)"
        return $false
    }
}

<#
.SYNOPSIS
    Create a new folder in SSRS.

.DESCRIPTION
    Creates a new folder in the SSRS Report Server.

.PARAMETER FolderPath
    The path where the folder should be created.

.EXAMPLE
    New-SSRSFolder -FolderPath "/Reports/Sales"
#>
function New-SSRSFolder {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$FolderPath
    )
    
    New-SSRSFolder -FolderPath $FolderPath
}

<#
.SYNOPSIS
    Get content from an SSRS folder.

.DESCRIPTION
    Retrieves the content (items) from an SSRS folder.

.PARAMETER RsFolder
    The SSRS folder path to query.

.PARAMETER Recurse
    Include subfolders recursively.

.EXAMPLE
    Get-SSRSFolderContent -RsFolder "/Reports"
#>
function Get-SSRSFolderContent {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $true)]
        [string]$RsFolder,
        
        [Parameter(Mandatory = $false)]
        [switch]$Recurse
    )
    
    Get-RsFolderContent -RsFolder $RsFolder -Recurse:$Recurse
}

#endregion

#region Aliases

# Create aliases for common functions
New-Alias -Name "Deploy-Reports" -Value "Deploy-SSRS" -Force
New-Alias -Name "Connect-SSRS" -Value "Connect-SSRSServer" -Force
New-Alias -Name "Test-SSRS" -Value "Test-SSRSConnection" -Force

# Backward compatibility alias
New-Alias -Name "Deploy-SSRS" -Value "Invoke-SSRSDeployment" -Force

#endregion

#region Module Cleanup

# Export module members
Export-ModuleMember -Function @(
    'Invoke-SSRSDeployment',
    'Connect-SSRSServer',
    'Test-SSRSConnection',
    'New-SSRSFolder',
    'Get-SSRSFolderContent'
) -Alias @(
    'Deploy-SSRS',
    'Deploy-Reports',
    'Connect-SSRS', 
    'Test-SSRS'
)

#endregion
