# ======================================================================
# Enterprise-SSRS-Deployment-Framework - Logging Module
# Contains all logging and output functions
# ======================================================================

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet("INFO", "WARNING", "ERROR", "SUCCESS")]
        [string]$Level = "INFO"
    )
    
    $TimeStamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $LogMessage = "[$TimeStamp] [$Level] $Message"
    
    # Color coding for console output
    switch ($Level) {
        "INFO"    { Write-Host $LogMessage -ForegroundColor Cyan }
        "WARNING" { Write-Host $LogMessage -ForegroundColor Yellow }
        "ERROR"   { Write-Host $LogMessage -ForegroundColor Red }
        "SUCCESS" { Write-Host $LogMessage -ForegroundColor Green }
    }
    
    # Write to log file if $LogFile is available in global scope
    if ($Global:LogFile -and (Test-Path (Split-Path $Global:LogFile -Parent))) {
        Add-Content -Path $Global:LogFile -Value $LogMessage
    }
}

function Write-Banner {
    param([string]$Title)
    
    $Banner = @"

============================================================================
$Title
============================================================================
"@
    Write-Log $Banner
}

function Initialize-Logging {
    param(
        [string]$ScriptPath
    )
    
    $LogPath = Join-Path $ScriptPath "Logs"
    $TimeStamp = Get-Date -Format "yyyyMMdd_HHmmss"
    $Global:LogFile = Join-Path $LogPath "SSRS_Deployment_$TimeStamp.log"
    
    # Ensure log directory exists
    if (!(Test-Path $LogPath)) {
        New-Item -ItemType Directory -Path $LogPath -Force | Out-Null
    }
    
    return $Global:LogFile
}

# Functions are available when dot-sourced
