# SSRS Authentication Configuration

This document explains the authentication options available for SSRS deployment.

## Authentication Methods

The deployment script supports multiple authentication methods with the following priority order:

### 1. Direct Username and Password Parameters (Highest Priority)
Pass username and password directly as command line parameters:

```powershell
.\Deploy-SSRS.ps1 -Environment "Prod" -User "datasciencetrial@outlook.com" -Pwd "YourPassword"
```

### 2. Runtime Credential Parameter
Pass credentials directly when calling the script:

```powershell
$Cred = Get-Credential
.\Deploy-SSRS.ps1 -Environment "Prod" -Credential $Cred
```

### 3. Runtime Credential Prompt
Use the `-PromptForCredentials` switch to be prompted for credentials:

```powershell
.\Deploy-SSRS.ps1 -Environment "Prod" -PromptForCredentials
```

### 4. Configuration-Based Prompting
Set `PromptForCredentials` to `true` in the config file:

```json
{
  "Security": {
    "Authentication": {
      "PromptForCredentials": true
    }
  }
}
```

### 5. Current User Windows Authentication (Default)
Uses the current Windows user context (default behavior):

```json
{
  "Security": {
    "Authentication": {
      "UseCurrentUser": true
    }
  }
}
```

### 6. Configuration Username (Prompts for Password)
Specify username in config, will prompt for password at runtime:

```json
{
  "Security": {
    "Authentication": {
      "UseCurrentUser": false,
      "Domain": "MYDOMAIN",
      "Username": "serviceaccount"
    }
  }
}
```

## Configuration Options

### Authentication Section
```json
{
  "Security": {
    "Authentication": {
      "UseCurrentUser": true,          // Use current Windows user
      "PromptForCredentials": false,   // Prompt for credentials
      "Domain": "",                    // Domain for username
      "Username": ""                   // Username (will prompt for password)
    }
  }
}
```

### Configuration Properties

- **UseCurrentUser**: `true` (default) - Use current Windows user authentication
- **PromptForCredentials**: `false` (default) - Set to `true` to always prompt for credentials
- **Domain**: Optional domain name for the username
- **Username**: Optional username (will prompt for password if provided)

## Usage Examples

### Example 1: Direct Username and Password
```powershell
# Using variables (recommended for automation)
$User = "datasciencetrial@outlook.com"
$Pwd = "********"  # Replace with actual password
.\Deploy-SSRS.ps1 -Environment "Prod" -User $User -Pwd $Pwd

# Direct method (password visible in command history)
.\Deploy-SSRS.ps1 -Environment "Prod" -User "datasciencetrial@outlook.com" -Pwd "********"
```

### Example 2: Use Current User (Default)
```powershell
.\Deploy-SSRS.ps1 -Environment "Dev"
```

### Example 3: Prompt for Credentials
```powershell
.\Deploy-SSRS.ps1 -Environment "Prod" -PromptForCredentials
```

### Example 4: Pass Credentials Directly
```powershell
$Cred = Get-Credential -UserName "DOMAIN\serviceaccount"
.\Deploy-SSRS.ps1 -Environment "Prod" -Credential $Cred
```

### Example 5: Configure Username in Config File
Set this in `deployment-config.json`:
```json
{
  "Security": {
    "Authentication": {
      "UseCurrentUser": false,
      "Domain": "MYDOMAIN",
      "Username": "ssrs-deploy-account"
    }
  }
}
```

Then run:
```powershell
.\Deploy-SSRS.ps1 -Environment "Prod"
```
The script will prompt: "Enter password for MYDOMAIN\ssrs-deploy-account"

## Security Best Practices

### Password Security
- ✅ **Use variables** to store passwords and avoid command history exposure
- ✅ **Use credential prompts** for interactive deployments
- ✅ **Passwords are automatically masked** in deployment logs
- ⚠️ **Be cautious with direct password parameters** - they appear in command history
- ❌ **Never store passwords in scripts or configuration files**

### Secure Usage Examples
```powershell
# RECOMMENDED: Using variables
$User = "your-username"
$Pwd = "your-password"
.\Deploy-SSRS.ps1 -Environment "Prod" -User $User -Pwd $Pwd

# RECOMMENDED: Interactive prompt
.\Deploy-SSRS.ps1 -Environment "Prod" -PromptForCredentials

# CAUTION: Direct usage (visible in history)
.\Deploy-SSRS.ps1 -Environment "Prod" -User "username" -Pwd "password"
```

### Authentication Logging
The deployment script automatically masks passwords in logs:
```
[INFO] Using provided username and password for user: username (password masked)
[INFO] Authentication: Using credentials for username
```
