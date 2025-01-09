<#
.SYNOPSIS
    Detect if the computer's secure channel with the domain is intact.

.DESCRIPTION
    This script checks if the computer's secure channel with the domain controller is functional. If the secure channel is broken, the computer may experience the "Trust relationship between this workstation and the primary domain failed" error. 
    The detection script identifies this issue by using the `Test-ComputerSecureChannel` cmdlet and exits with the appropriate status code.

.PARAMETER None
    No parameters are required.

.EXAMPLE
    Run this script in Intune Proactive Remediation:
    Detection script will return:
    - Exit code 0: Secure channel is intact.
    - Exit code 1: Secure channel is broken.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-01-09
#>

Write-Host "Checking the status of the secure channel with the domain..."
try {
    # Test if the secure channel with the domain is intact
    $SecureChannelStatus = Test-ComputerSecureChannel -Verbose
    if ($SecureChannelStatus) {
        Write-Host "Secure channel with the domain is intact." -ForegroundColor Green
        exit 0  # Secure channel is working
    } else {
        Write-Host "Secure channel with the domain is broken." -ForegroundColor Red
        exit 1  # Secure channel is broken
    }
} catch {
    Write-Host "Error while checking the secure channel: $_" -ForegroundColor Red
    exit 1  # Any errors will exit with failure
}
