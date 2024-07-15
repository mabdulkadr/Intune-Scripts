<#
.SYNOPSIS
    Remediation Script to update all installed applications using winget.

.DESCRIPTION
    This script uses winget to update all installed applications on the system.
    It requires administrative privileges to run and will output the progress of the update process.

.EXAMPLE
    .\RemediatePendingAppUpdates.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Remediation script
$logPath = "C:\Intune\Updates\RemediatePendingAppsUpdates.log"
if (!(Test-Path "C:\Intune\Updates")) {
    New-Item -ItemType Directory -Path "C:\Intune\Updates" -Force
}

$installedApps = winget list
$updatableApps = $installedApps | Select-String -Pattern "Available" | ForEach-Object { $_.Line.Split("|")[0].Trim() }

foreach ($app in $updatableApps) {
    Write-Output "Updating $app..." | Out-File -FilePath $logPath -Append
    winget upgrade --id $app --silent | Out-File -FilePath $logPath -Append
}

Write-Output "All apps have been updated." | Out-File -FilePath $logPath -Append
