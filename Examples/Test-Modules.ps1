# Example: Using Modular Components
# This example shows how to use individual modules

# Load the logging module
. .\Modules\Logging.ps1

# Initialize logging
$LogFile = Initialize-Logging -ScriptPath $PWD

# Use logging functions
Write-Log "Starting modular component test" -Level "INFO"
Write-Log "Testing warning message" -Level "WARNING"
Write-Log "Testing error message" -Level "ERROR"
Write-Log "Testing success message" -Level "SUCCESS"

Write-Banner "MODULAR COMPONENT TEST"

Write-Log "Modular logging test completed successfully!" -Level "SUCCESS"
Write-Log "Log file created at: $LogFile" -Level "INFO"

# Example: Testing configuration module
Write-Host "`nTesting Configuration Module:" -ForegroundColor Yellow

# Load configuration module
. .\Modules\Configuration.ps1

# Test configuration loading
try {
    $Config = Get-DeploymentConfig -ConfigFilePath "Deploy\Config\deployment-config.json"
    Write-Log "Configuration loaded successfully with $($Config.Environments.Count) environments" -Level "SUCCESS"
    
    # Show available environments
    foreach ($env in $Config.Environments.PSObject.Properties.Name) {
        Write-Log "  Environment: $env - Server: $($Config.Environments.$env.ReportServerUrl)" -Level "INFO"
    }
}
catch {
    Write-Log "Failed to load configuration: $($_.Exception.Message)" -Level "ERROR"
}

Write-Host "`nModular component test completed!" -ForegroundColor Green
