<#
.SYNOPSIS
    Detection Script to check for pending application updates using winget.

.DESCRIPTION
    This script checks if there are any pending application updates on the system using winget.
    It will return a non-zero exit code if updates are available and zero if no updates are pending.

.EXAMPLE
    .\DetectPendingAppUpdates.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Detection script
$logPath = "C:\Intune\Updates\DetectPendingAppsUpdates.log"
if (!(Test-Path "C:\Intune\Updates")) {
    New-Item -ItemType Directory -Path "C:\Intune\Updates" -Force
}

$installedApps = winget list
$updatesAvailable = $installedApps | Select-String -Pattern "Available"

if ($updatesAvailable) {
    $installedApps | Out-File -FilePath $logPath -Append
    Write-Output "Updates are available" | Out-File -FilePath $logPath -Append
    exit 1
} else {
    Write-Output "No updates available" | Out-File -FilePath $logPath -Append
    exit 0
}
