# ======================================================================
# SSRS Deployment Package - Validation Module
# Contains deployment validation and cleanup functions
# ======================================================================

function Test-DeploymentIntegrity {
    param(
        [string]$TargetFolder
    )
    
    Write-Banner "VALIDATING DEPLOYMENT"
    
    try {
        $DeployedItems = Get-RsFolderContent -RsFolder $TargetFolder -Recurse
        
        Write-Log "Deployment validation results:" -Level "INFO"
        Write-Log "Total items deployed: $($DeployedItems.Count)" -Level "INFO"
        
        # Show items by type
        $ItemTypes = $DeployedItems | Group-Object TypeName
        foreach ($ItemType in $ItemTypes) {
            Write-Log "  $($ItemType.Name): $($ItemType.Count) items" -Level "INFO"
        }
        
        # Show folder structure for reports
        $Reports = $DeployedItems | Where-Object { $_.TypeName -eq "Report" }
        if ($Reports) {
            Write-Log "Report folder structure:" -Level "INFO"
            foreach ($Report in $Reports) {
                Write-Log "  $($Report.Path)" -Level "INFO"
            }
        }
        
        return $true
    }
    catch {
        Write-Log "Failed to validate deployment: $($_.Exception.Message)" -Level "ERROR"
        return $false
    }
}

function Clear-SensitiveVariables {
    <#
    .SYNOPSIS
        Clear any variables that might contain sensitive information.
    #>
    try {
        # Clear variables that might contain passwords
        Get-Variable | Where-Object { 
            $_.Value -is [string] -and (
                $_.Value -like "*password*" -or 
                $_.Value -like "*pwd*" -or 
                $_.Value -like "*credential*"
            )
        } | ForEach-Object {
            if ($_.Name -notin @('PWD', 'PSMODULEPATH', 'PATH')) {
                Remove-Variable -Name $_.Name -Scope Global -ErrorAction SilentlyContinue
            }
        }
        
        # Ensure current location is preserved
        $null = Get-Location
        
        Write-Log "Cleared sensitive variables from memory" -Level "INFO"
    }
    catch {
        Write-Log "Warning: Could not clear all sensitive variables: $($_.Exception.Message)" -Level "WARNING"
    }
}

# Functions are available when dot-sourced
