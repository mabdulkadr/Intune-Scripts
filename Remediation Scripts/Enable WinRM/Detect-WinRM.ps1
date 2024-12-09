<#
.SYNOPSIS
    Checks if WinRM (PowerShell Remoting) is enabled on the device.

.DESCRIPTION
    Uses Test-WSMan to verify if PSRemoting is functional. If enabled, no remediation is required.
    If disabled, remediation will be triggered.

.NOTES
    Exit codes:
    0 = WinRM/PSRemoting is enabled
    1 = WinRM/PSRemoting is not enabled

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Attempt to test PSRemoting
try {
    $testResult = Test-WSMan -ErrorAction Stop
    if ($testResult) {
        # WinRM enabled
        Write-Host "WinRM is enabled on this device."
        Exit 0
    } else {
        # This should rarely occur since Test-WSMan normally throws an error if not functional
        Write-Host "WinRM test did not return a valid result."
        Exit 1
    }
} catch {
    # If an error is thrown, WinRM is likely not enabled
    Write-Host "WinRM appears to be disabled or not functioning properly."
    Exit 1
}
