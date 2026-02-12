# Security Policy

## Supported Versions

We take security seriously and actively maintain the following versions of the Enterprise SSRS Deployment Framework:

| Version | Supported          |
| ------- | ------------------ |
| Latest  | :white_check_mark: |
| < Latest| :x:                |

We recommend always using the latest version to ensure you have the most recent security updates and bug fixes.

## Reporting a Vulnerability

We appreciate your efforts to responsibly disclose your findings and will make every effort to acknowledge your contributions.

### How to Report a Security Vulnerability

**Please do not report security vulnerabilities through public GitHub issues.**

Instead, please report security vulnerabilities by:

1. **Creating a private security advisory** on GitHub:
   - Navigate to the [Security Advisories](https://github.com/datasciencetrialgit/Enterprise-SSRS-Deployment-Framework/security/advisories) page
   - Click "Report a vulnerability"
   - Provide detailed information about the vulnerability

2. **Via email** (if GitHub security advisories are not available):
   - Send details to the repository maintainers
   - Include the word "SECURITY" in the subject line
   - Provide detailed information about the vulnerability

### What to Include in Your Report

Please include the following information in your report:

- **Type of vulnerability** (e.g., SQL injection, credential exposure, etc.)
- **Full path** of the affected file(s)
- **Location** in the codebase where the vulnerability exists
- **Step-by-step instructions** to reproduce the issue
- **Proof-of-concept or exploit code** (if possible)
- **Impact assessment** - what an attacker might be able to achieve
- **Suggested fix** (if you have one)

### What to Expect

After you submit a vulnerability report, you can expect:

1. **Acknowledgment**: We will acknowledge receipt of your report within 48 hours
2. **Initial Assessment**: We will provide an initial assessment within 5 business days
3. **Updates**: We will keep you informed of our progress throughout the investigation
4. **Resolution**: Once the vulnerability is fixed, we will:
   - Notify you before the public disclosure
   - Credit you in the security advisory (unless you prefer to remain anonymous)
   - Release a security update

### Security Best Practices for Users

When using the Enterprise SSRS Deployment Framework, please follow these security best practices:

1. **Credential Management**
   - Never hardcode credentials in scripts or configuration files
   - Use secure credential storage mechanisms (e.g., Azure Key Vault, GitHub Secrets)
   - Rotate credentials regularly
   - Use service accounts with minimal required permissions

2. **Network Security**
   - Always use HTTPS for production SSRS connections
   - Restrict network access to SSRS servers
   - Use VPNs or private networks for deployment operations

3. **Access Control**
   - Follow the principle of least privilege
   - Use separate service accounts for different environments
   - Regularly review and audit permissions
   - Enable audit logging on SSRS servers

4. **CI/CD Security**
   - Store all secrets as encrypted variables in your CI/CD platform
   - Use dedicated service accounts for automated deployments
   - Limit access to CI/CD pipelines and secrets
   - Review pipeline logs for sensitive data exposure

5. **Code Security**
   - Keep PowerShell and dependencies up to date
   - Review deployment logs for errors or warnings
   - Test deployments in non-production environments first
   - Use `-WhatIf` parameter to validate changes before applying

6. **Configuration Security**
   - Protect configuration files containing environment settings
   - Use environment variables for sensitive configuration
   - Never commit credentials to version control
   - Regularly review and update security policies

### Known Security Considerations

The following security considerations are inherent to the framework's design:

1. **Credential Handling**: The framework supports passing credentials as parameters for automation. Ensure these are properly secured in your CI/CD pipeline or automation scripts.

2. **Connection Strings**: Configuration files may contain connection strings. Ensure these files are properly secured and not exposed in public repositories.

3. **SSRS Permissions**: The deployment account needs appropriate permissions on the SSRS server. Follow the principle of least privilege.

4. **Log Files**: Deployment logs may contain sensitive information. Ensure log directories have appropriate access controls.

### Scope

This security policy applies to:

- All PowerShell scripts in this repository
- Configuration handling and credential management
- SSRS server communication and authentication
- CI/CD integration examples and documentation

### Attribution

We believe in recognizing security researchers who help improve our project. If you report a valid security vulnerability, we will:

- Publicly acknowledge your contribution (with your permission)
- Include your name in the security advisory
- Credit you in the release notes

Thank you for helping keep the Enterprise SSRS Deployment Framework and its users safe!
