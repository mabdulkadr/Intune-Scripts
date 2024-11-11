<#
.SYNOPSIS
    Detects if the device is running Windows 10 and needs the Windows 11 upgrade notification.

.DESCRIPTION
    This script checks the current operating system version. If the device is running Windows 10, it exits with code 1, indicating that remediation (displaying the Windows 11 upgrade notification) is needed. If the device is already running Windows 11, it exits with code 0.

.HINT
    This is a community script. There is no guarantee for this. Please check thoroughly before running.

.RUN AS
    User

.EXAMPLE
    .\Detect_Windows11UpgradeNotification.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-11

#>

# Get the product name of the operating system
$ProductName = (Get-ItemProperty "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion").ProductName

if ($ProductName -like "*Windows 10*") {
    # Device is running Windows 10
    # Remediation needed (show upgrade notification)
    Write-Host "Device is running Windows 10"
    Exit 1
} elseif ($ProductName -like "*Windows 11*") {
    # Device is already on Windows 11
    Write-Host "Device is already on Windows 11"
    Exit 0
} else {
    # Device is running an unsupported OS version
    # No action needed
    Write-Host "Device is running an unsupported OS version"
    Exit 0
}
