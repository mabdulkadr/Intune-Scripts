<#
.SYNOPSIS
    Detection Script to check for pending Windows updates, excluding firmware updates.

.DESCRIPTION
    This script checks if there are any pending Windows updates on the system, excluding firmware updates.
    It will return a non-zero exit code if updates are available and zero if no updates are pending.

.EXAMPLE
    .\DetectPendingUpdates.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Detection script
$logPath = "C:\Intune\Updates\DetectPendingWindowsUpdates.log"
if (!(Test-Path "C:\Intune\Updates")) {
    New-Item -ItemType Directory -Path "C:\Intune\Updates" -Force
}

$Updates = (New-Object -ComObject Microsoft.Update.Session).CreateUpdateSearcher().Search("IsInstalled=0 AND Type='Software' AND IsHidden=0").Updates
if ($Updates.Count -gt 0) {
    $Updates | ForEach-Object { $_.Title } | Out-File -FilePath $logPath -Append
    Write-Output "Updates are pending" | Out-File -FilePath $logPath -Append
    exit 1
} else {
    Write-Output "No updates pending" | Out-File -FilePath $logPath -Append
    exit 0
}
