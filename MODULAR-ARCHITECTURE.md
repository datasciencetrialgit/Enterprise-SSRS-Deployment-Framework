# Enterprise-SSRS-Deployment-Framework - Modular Architecture

## Overview
The Enterprise-SSRS-Deployment-Framework has been split into a modular architecture for better maintainability and separation of concerns.

## Current Structure

### Core Files (Keep as-is)
- `Deploy-SSRS.ps1` - **Main deployment script** (working version)
- `SSRS-Core-Functions.ps1` - Core SSRS connectivity functions
- `SSRS-Helper-Functions.ps1` - RDL/RSD reference processing functions

### New Modular Components (`Modules/` folder)
The functionality from `Deploy-SSRS.ps1` has been logically separated into:

#### 1. `Modules/Logging.ps1`
- **Functions:** `Write-Log`, `Write-Banner`, `Initialize-Logging`
- **Purpose:** All logging and console output functionality
- **Usage:** Handles colored console output and log file management

#### 2. `Modules/Configuration.ps1`
- **Functions:** `Get-DeploymentConfig`, `New-DefaultConfig`
- **Purpose:** Configuration file loading and default config creation
- **Usage:** Manages deployment-config.json reading and validation

#### 3. `Modules/Connection.ps1`
- **Functions:** `Test-SSRSConnection`, `Resolve-SSRSCredentials`
- **Purpose:** SSRS server connection and authentication
- **Usage:** Handles all authentication methods and connection testing

#### 4. `Modules/DataSources.ps1`
- **Functions:** `Publish-DataSources`
- **Purpose:** Data source deployment logic
- **Usage:** Processes .rds files and creates data sources on SSRS

#### 5. `Modules/DataSets.ps1`
- **Functions:** `Publish-DataSets`
- **Purpose:** Dataset deployment logic
- **Usage:** Processes .rsd files with reference updating and deploys shared datasets

#### 6. `Modules/Reports.ps1`
- **Functions:** `Publish-Reports`
- **Purpose:** Report deployment logic
- **Usage:** Processes .rdl files with reference updating and folder structure preservation

#### 7. `Modules/Validation.ps1`
- **Functions:** `Test-DeploymentIntegrity`, `Clear-SensitiveVariables`
- **Purpose:** Deployment validation and security cleanup
- **Usage:** Validates successful deployment and clears sensitive data

## Benefits of Modular Architecture

### ✅ **Better Maintainability**
- Each module has a single responsibility
- Easier to locate and fix issues
- Cleaner code organization

### ✅ **Enhanced Testability**
- Individual modules can be tested in isolation
- Easier to write unit tests for specific functionality
- Better debugging capabilities

### ✅ **Improved Reusability**
- Modules can be used independently
- Easy to create specialized deployment scripts
- Functions can be imported as needed

### ✅ **Simplified Development**
- Developers can focus on specific areas
- Reduced file size and complexity
- Better version control and change tracking

## Migration Strategy

### Phase 1: Current State ✅
- Keep existing `Deploy-SSRS.ps1` working
- Create modular components in `Modules/` folder
- Document the new structure

### Phase 2: Gradual Migration (Future)
When ready to migrate:

1. **Test modules independently**
   ```powershell
   # Test a specific module
   . .\Modules\Logging.ps1
   Initialize-Logging -ScriptPath $PWD
   Write-Log "Test message" -Level "INFO"
   ```

2. **Create new main script**
   - Replace current monolithic script with module-loading version
   - Import all required modules
   - Call modular functions

3. **Validate functionality**
   - Ensure all existing features work
   - Test all deployment scenarios
   - Verify logging and error handling

## Usage Examples

### Using Individual Modules
```powershell
# Load specific functionality
. .\Modules\Logging.ps1
. .\Modules\Configuration.ps1

# Use module functions
$LogFile = Initialize-Logging -ScriptPath $PWD
$Config = Get-DeploymentConfig -ConfigFilePath "Deploy\Config\deployment-config.json"
Write-Log "Configuration loaded" -Level "SUCCESS"
```

### Creating Specialized Scripts
```powershell
# Data sources only deployment
. .\Modules\Logging.ps1
. .\Modules\DataSources.ps1
. .\SSRS-Core-Functions.ps1

$LogFile = Initialize-Logging -ScriptPath $PWD
Publish-DataSources -Config $Config -Environment "Dev" -DataSourcesPath "Deploy\Data Sources"
```

## Current Deployment (No Changes Needed)

The current `Deploy-SSRS.ps1` continues to work exactly as before:

```powershell
# Standard deployment (unchanged)
.\Deploy-SSRS.ps1

# With parameters (unchanged)
.\Deploy-SSRS.ps1 -Environment "Prod" -ReportServerUrl "http://prodserver/ReportServer"
```

## File Organization

```
Enterprise-SSRS-Deployment-Framework/
├── Deploy-SSRS.ps1                    # Main script (current working version)
├── Deploy-SSRS-Original-Backup.ps1    # Backup of original
├── SSRS-Core-Functions.ps1             # Core SSRS functions
├── SSRS-Helper-Functions.ps1           # RDL/RSD processing
├── Modules/                            # New modular components
│   ├── Logging.ps1                     # Logging functions
│   ├── Configuration.ps1               # Config management
│   ├── Connection.ps1                  # SSRS connection
│   ├── DataSources.ps1                 # Data source deployment
│   ├── DataSets.ps1                    # Dataset deployment
│   ├── Reports.ps1                     # Report deployment
│   └── Validation.ps1                  # Validation & cleanup
├── Deploy/
│   ├── Config/
│   ├── Data Sources/
│   ├── DataSets/
│   └── RDL-Files/
└── Logs/
```

## Next Steps

1. **Keep using current `Deploy-SSRS.ps1`** - No changes needed for day-to-day usage
2. **Review modular components** - Examine individual modules for understanding
3. **Plan migration** - When ready, test and migrate to modular version
4. **Customize as needed** - Create specialized scripts using individual modules

The modular architecture is now available for future enhancements while maintaining full backward compatibility!
