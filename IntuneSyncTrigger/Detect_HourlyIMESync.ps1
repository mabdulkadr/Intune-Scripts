<#
.SYNOPSIS
    Detects if Intune Management Extension sync has occurred within the last hour.

.DESCRIPTION
    This script checks the Event Log for IME sync events (Event ID 208) in the past hour.
    If no sync event is found, the detection fails.

.EXAMPLE
 .\Detect_HourlyIMESync.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# Define variables
$TimeFrame = (Get-Date).AddHours(-1)
$LogName = "Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational"
$EventID = 208  # IME Sync Event ID

# Check for the IME sync event in the log
$SyncEvent = Get-WinEvent -LogName $LogName -FilterXPath "*[System[EventID=$EventID and TimeCreated[timediff(@SystemTime) <= 3600000]]]" -ErrorAction SilentlyContinue

if ($SyncEvent) {
    Write-Output "Intune Management Extension Sync detected within the last hour."
    exit 0  # Compliance
}
else {
    Write-Output "No Intune Management Extension Sync detected within the last hour."
    exit 1  # Non-compliance
}
