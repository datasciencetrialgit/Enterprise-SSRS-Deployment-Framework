# Deploy Directory

This directory contains the deployment artifacts and configurations used during SSRS deployment.

## Structure

- **Config/**: Environment-specific configuration files
- **DataSources/**: Data source definition files (.rds)
- **DataSets/**: Shared dataset files (.rsd)
- **RDL-Files/**: Report definition files (.rdl)

## Usage

The deployment script will automatically use files from this directory structure when deploying to SSRS.

Files in this directory take precedence over files in the root project directories during deployment.
