<#
.SYNOPSIS
    Detects outdated applications using Winget, excluding Java-related applications.

.DESCRIPTION
    This script checks for outdated applications using Winget while filtering out Java-related apps (OpenJDK, JDK, JRE).
    If any non-Java application requires an update, it returns `"Non-Compliant"`.
    Otherwise, it returns `"Compliant"`.

.EXAMPLE
    Run this script in Microsoft Intune as a compliance detection rule.

.NOTES
    Author: Your Name
    Date: YYYY-MM-DD
    Tested on: Windows 10/11 (Intune-managed)
#>

# Ensure Winget is available
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
    Write-Output "Winget not found. Device is Non-Compliant."
    exit 1
}

# Get list of outdated applications
$OutdatedApps = winget upgrade --accept-source-agreements | Select-String -Pattern "(\S+)\s+(\S+)\s+(\S+)" | ForEach-Object { $_.ToString() }

# Exclude Java-related applications (JDK, JRE, OpenJDK)
$ExcludedApps = @("jdk", "jre", "openjdk")
$FilteredApps = $OutdatedApps | Where-Object { $ExcludedApps -notcontains ($_ -split '\s+')[0].ToLower() }

# Check if there are non-Java apps that need updating
if ($FilteredApps) {
    Write-Output "Non-Compliant"
    exit 1
} else {
    Write-Output "Compliant"
    exit 0
}
