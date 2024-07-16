<#
.SYNOPSIS
    Remediation Script to force a Group Policy update.

.DESCRIPTION
    This script forces a Group Policy update using the gpupdate /force command.

.EXAMPLE
    .\RemediateGroupPolicyUpdate.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-16
#>

# Force Group Policy update
try {
    Write-Output "Forcing Group Policy update..."
    gpupdate /force

    Write-Output "Success: Group Policy update forced."
    exit 0
} catch {
    Write-Output "Error: Failed to force Group Policy update."
    exit 1
}
