# ======================================================================
# SSRS Deployment Package - Connection Module
# Contains SSRS connection and authentication functions
# ======================================================================

function Test-SSRSConnection {
    param(
        [string]$ServerUrl,
        [System.Management.Automation.PSCredential]$Credential
    )
    
    Write-Log "Testing connection to SSRS server: $ServerUrl" -Level "INFO"
    
    try {
        if ($Credential) {
            Write-Log "Connecting with provided credentials for user: $($Credential.UserName)" -Level "INFO"
            Connect-RsReportServer -ReportServerUri $ServerUrl -Credential $Credential
        } else {
            Write-Log "Connecting with current user Windows authentication" -Level "INFO"
            Connect-RsReportServer -ReportServerUri $ServerUrl
        }
        
        # Test the connection by getting server version
        $null = Get-RsFolderContent -RsFolder "/"
        Write-Log "Successfully connected to SSRS server" -Level "SUCCESS"
        return $true
    }
    catch {
        Write-Log "Failed to connect to SSRS server: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Resolve-SSRSCredentials {
    param(
        [System.Management.Automation.PSCredential]$ProvidedCredential,
        [object]$Config,
        [switch]$PromptForCredentials,
        [string]$User,
        [System.Diagnostics.CodeAnalysis.SuppressMessageAttribute('PSAvoidUsingPlainTextForPassword', '', Justification = 'Backward compatibility')]
        [string]$Password
    )
    
    Write-Log "Resolving authentication credentials..." -Level "INFO"
    Write-Log "Config: UseCurrentUser=$($Config.Security.Authentication.UseCurrentUser), PromptForCredentials=$($Config.Security.Authentication.PromptForCredentials)" -Level "INFO"
    Write-Log "Parameters: PromptForCredentials=$($PromptForCredentials.IsPresent), User=$User" -Level "INFO"
    
    # Priority 1: Use provided User and Password parameters
    if ($User -and $Password) {
        Write-Log "Using provided username and password for user: $User" -Level "INFO"
        try {
            $SecurePassword = ConvertTo-SecureString $Password -AsPlainText -Force
            $Credential = New-Object System.Management.Automation.PSCredential($User, $SecurePassword)
            return $Credential
        }
        catch {
            Write-Log "Failed to create credential from User/Password parameters: $($_.Exception.Message)" -Level "WARNING"
        }
    }
    
    # Priority 2: Use provided credential parameter
    if ($ProvidedCredential) {
        Write-Log "Using provided credential for user: $($ProvidedCredential.UserName)" -Level "INFO"
        return $ProvidedCredential
    }
    
    # Priority 3: Use current user if configured (default)
    if ($Config.Security.Authentication.UseCurrentUser -and -not $PromptForCredentials.IsPresent -and -not $Config.Security.Authentication.PromptForCredentials) {
        Write-Log "Using current user Windows authentication" -Level "INFO"
        return $null  # null means use current user context
    }
    
    # Priority 4: Check if prompt is requested or configured
    if ($PromptForCredentials.IsPresent -or $Config.Security.Authentication.PromptForCredentials) {
        Write-Log "Prompting for credentials..." -Level "INFO"
        
        try {
            $Cred = Get-Credential -Message "Enter credentials for SSRS Report Server authentication"
            if ($Cred) {
                Write-Log "Credentials provided for user: $($Cred.UserName)" -Level "INFO"
                return $Cred
            } else {
                Write-Log "Credential prompt was cancelled by user" -Level "WARNING"
                Write-Log "Deployment cannot continue without proper authentication" -Level "ERROR"
                throw "Authentication cancelled by user. Deployment stopped."
            }
        }
        catch [System.Management.Automation.ParameterBindingException] {
            Write-Log "Credential prompt was cancelled by user" -Level "WARNING"
            Write-Log "Deployment cannot continue without proper authentication" -Level "ERROR"
            throw "Authentication cancelled by user. Deployment stopped."
        }
        catch {
            Write-Log "Failed to get credentials from prompt: $($_.Exception.Message)" -Level "WARNING"
            throw "Failed to obtain credentials. Deployment stopped."
        }
    }
    
    # Priority 5: Use current user if configured (fallback)
    if ($Config.Security.Authentication.UseCurrentUser) {
        Write-Log "Using current user Windows authentication (fallback)" -Level "INFO"
        return $null  # null means use current user context
    }
    
    # Priority 5: Create credential from config if username is provided
    if ($Config.Security.Authentication.Username -and $Config.Security.Authentication.Username.Trim() -ne "") {
        Write-Log "Creating credential from configuration for user: $($Config.Security.Authentication.Username)" -Level "INFO"
        
        # Prompt for password since we shouldn't store passwords in config
        try {
            $Username = if ($Config.Security.Authentication.Domain) {
                "$($Config.Security.Authentication.Domain)\$($Config.Security.Authentication.Username)"
            } else {
                $Config.Security.Authentication.Username
            }
            
            $SecurePassword = Read-Host "Enter password for $Username" -AsSecureString
            return New-Object System.Management.Automation.PSCredential($Username, $SecurePassword)
        }
        catch {
            Write-Log "Failed to create credential from config: $($_.Exception.Message)" -Level "WARNING"
        }
    }
    
    # Fallback: Use current user
    Write-Log "Falling back to current user Windows authentication" -Level "INFO"
    return $null
}

# Functions are available when dot-sourced
