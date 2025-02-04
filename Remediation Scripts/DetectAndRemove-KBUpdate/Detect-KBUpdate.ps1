<#
.SYNOPSIS
    Detection script to check if a specific Windows update (KBxxxxxxx) is installed.

.DESCRIPTION
    This script is designed for Microsoft Intune remediation policies. It checks whether
    a specific KB update is installed on the system. If the update is found, it exits with code 1 (non-compliant).
    If not found, it exits with code 0 (compliant).

.EXAMPLE
    .\Detect-KBUpdate.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date: 2025-02-04
#>

$KBNumber = "KB5050094"

# Check if the KB update is installed
$update = Get-HotFix | Where-Object { $_.HotFixID -eq $KBNumber }

if ($update) {
    Write-Host "$KBNumber is installed. Remediation required."
    exit 1  # Exit code 1 indicates non-compliance
} else {
    Write-Host "$KBNumber is NOT installed. System is compliant."
    exit 0  # Exit code 0 indicates compliance
}
