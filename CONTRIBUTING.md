# Contributing to Enterprise SSRS Deployment Framework

Thank you for your interest in contributing to the Enterprise SSRS Deployment Framework! We welcome contributions from the community and are pleased to have you join us.

## Table of Contents

- [Code of Conduct](#code-of-conduct)
- [How Can I Contribute?](#how-can-i-contribute)
- [Getting Started](#getting-started)
- [Development Workflow](#development-workflow)
- [Coding Standards](#coding-standards)
- [Commit Guidelines](#commit-guidelines)
- [Pull Request Process](#pull-request-process)
- [Reporting Bugs](#reporting-bugs)
- [Suggesting Enhancements](#suggesting-enhancements)
- [Questions](#questions)

## Code of Conduct

This project and everyone participating in it is governed by our [Code of Conduct](CODE_OF_CONDUCT.md). By participating, you are expected to uphold this code. Please report unacceptable behavior to the project maintainers.

## How Can I Contribute?

### Reporting Bugs

Before creating bug reports, please check the existing issues to avoid duplicates. When you create a bug report, include as many details as possible:

- **Use a clear and descriptive title**
- **Describe the exact steps to reproduce the problem**
- **Provide specific examples** (code snippets, config files, etc.)
- **Describe the behavior you observed** and what you expected to see
- **Include screenshots** if applicable
- **Include environment details** (PowerShell version, SSRS version, OS, etc.)

### Suggesting Enhancements

Enhancement suggestions are tracked as GitHub issues. When creating an enhancement suggestion, include:

- **Use a clear and descriptive title**
- **Provide a detailed description** of the suggested enhancement
- **Explain why this enhancement would be useful** to most users
- **Provide examples** of how the enhancement would be used
- **List any alternative solutions** you've considered

### Contributing Code

We actively welcome your pull requests! Here's how you can contribute code:

1. Fork the repository
2. Create a feature branch from `main`
3. Make your changes following our coding standards
4. Test your changes thoroughly
5. Submit a pull request

## Getting Started

### Prerequisites

- PowerShell 5.1 or later
- SQL Server Reporting Services 2016 or later (for testing)
- Git for version control
- A code editor (VS Code recommended)

### Setting Up Your Development Environment

1. **Fork and Clone the Repository**
   ```bash
   git clone https://github.com/YOUR-USERNAME/Enterprise-SSRS-Deployment-Framework.git
   cd Enterprise-SSRS-Deployment-Framework
   ```

2. **Configure Git**
   ```bash
   git config user.name "Your Name"
   git config user.email "your.email@example.com"
   ```

3. **Create a Branch**
   ```bash
   git checkout -b feature/your-feature-name
   ```

4. **Test the Setup**
   ```powershell
   .\Deploy-SSRS.ps1 -Environment "Dev" -WhatIf
   ```

## Development Workflow

1. **Make Your Changes**
   - Write clean, maintainable code
   - Follow the existing code style
   - Add comments where necessary
   - Keep changes focused and minimal

2. **Test Your Changes**
   ```powershell
   # Test core functions
   . .\SSRS-Core-Functions.ps1
   
   # Test deployment script with WhatIf
   .\Deploy-SSRS.ps1 -Environment "Dev" -WhatIf
   ```

3. **Update Documentation**
   - Update README.md if you've added new features
   - Update inline comments and help text
   - Add examples for new functionality

4. **Commit Your Changes**
   ```bash
   git add .
   git commit -m "Add: Brief description of your changes"
   ```

5. **Push to Your Fork**
   ```bash
   git push origin feature/your-feature-name
   ```

6. **Submit a Pull Request**
   - Navigate to the original repository
   - Click "New Pull Request"
   - Select your branch
   - Fill out the PR template

## Coding Standards

### PowerShell Style Guide

Follow these guidelines when writing PowerShell code:

1. **Naming Conventions**
   - Use PascalCase for function names (e.g., `Deploy-SSRSReport`)
   - Use approved PowerShell verbs (Get, Set, New, Remove, etc.)
   - Use meaningful and descriptive variable names
   - Use PascalCase for parameters (e.g., `$ReportServerUrl`)

2. **Function Structure**
   ```powershell
   function Verb-Noun {
       [CmdletBinding()]
       param(
           [Parameter(Mandatory=$true)]
           [string]$RequiredParameter,
           
           [Parameter(Mandatory=$false)]
           [string]$OptionalParameter = "Default"
       )
       
       begin {
           # Initialization code
       }
       
       process {
           # Main logic
       }
       
       end {
           # Cleanup code
       }
   }
   ```

3. **Error Handling**
   - Use `try-catch-finally` blocks for error handling
   - Provide meaningful error messages
   - Use appropriate error actions (Stop, Continue, SilentlyContinue)
   
   ```powershell
   try {
       # Code that might fail
   }
   catch {
       Write-Error "Failed to perform operation: $_"
       throw
   }
   finally {
       # Cleanup code
   }
   ```

4. **Documentation**
   - Add comment-based help for all functions
   - Include synopsis, description, parameters, and examples
   
   ```powershell
   <#
   .SYNOPSIS
       Brief description of the function
   
   .DESCRIPTION
       Detailed description of what the function does
   
   .PARAMETER ParameterName
       Description of the parameter
   
   .EXAMPLE
       Verb-Noun -ParameterName "Value"
       Description of what this example does
   #>
   ```

5. **Code Formatting**
   - Use 4 spaces for indentation (no tabs)
   - Place opening braces on the same line
   - Use blank lines to separate logical sections
   - Keep lines under 120 characters when possible
   - Add spaces around operators

## Commit Guidelines

### Commit Message Format

Use clear and descriptive commit messages:

```
<type>: <subject>

<body>

<footer>
```

**Types:**
- `Add` New feature or functionality
- `Fix` Bug fix
- `Update` Changes to existing functionality
- `Refactor` Code refactoring without changing functionality
- `Docs` Documentation changes
- `Test` Adding or updating tests
- `Style` Code style changes (formatting, etc.)
- `Chore` Maintenance tasks

**Examples:**
```
Add: Support for deploying mobile reports

Implement functionality to deploy .rsmobile files to SSRS.
Includes validation and error handling.

Fixes #123
```

```
Fix: Credential validation error in Deploy-SSRS.ps1

Corrected parameter validation to properly handle PSCredential objects.
```

## Pull Request Process

1. **Before Submitting**
   - Ensure all tests pass
   - Update documentation as needed
   - Verify your code follows our standards
   - Rebase your branch on the latest `main`

2. **PR Description**
   - Clearly describe what changes you've made
   - Reference any related issues (e.g., "Fixes #123")
   - Include testing steps
   - Add screenshots for UI changes

3. **Review Process**
   - Maintainers will review your PR
   - Address any feedback or requested changes
   - Once approved, a maintainer will merge your PR

4. **After Merge**
   - Delete your feature branch
   - Pull the latest `main` branch
   - Celebrate your contribution! 🎉

## Reporting Bugs

When reporting bugs, use the bug report template and include:

- **Environment:** PowerShell version, SSRS version, OS
- **Steps to reproduce:** Detailed steps to recreate the issue
- **Expected behavior:** What you expected to happen
- **Actual behavior:** What actually happened
- **Error messages:** Full error messages or stack traces
- **Logs:** Relevant log file contents
- **Configuration:** Relevant configuration settings (sanitized)

## Suggesting Enhancements

When suggesting enhancements, consider:

- **Is it useful to most users?** Features should benefit the broader community
- **Is it feasible?** Consider technical constraints
- **Does it align with project goals?** Should fit the framework's purpose
- **Is there a workaround?** Mention if current functionality can achieve this

## Questions

Have questions about contributing? Here are some ways to get help:

- **GitHub Discussions:** Start a discussion for general questions
- **GitHub Issues:** Create an issue for specific problems or suggestions
- **README:** Check the README for usage documentation
- **Examples:** Look at the Examples folder for code samples

## Recognition

We value all contributions, including:

- Code contributions
- Documentation improvements
- Bug reports and testing
- Feature suggestions
- Community support

Contributors will be recognized in our release notes and project documentation.

## License

By contributing to the Enterprise SSRS Deployment Framework, you agree that your contributions will be licensed under the MIT License.

Thank you for contributing to make SSRS deployment easier for everyone! 🚀
