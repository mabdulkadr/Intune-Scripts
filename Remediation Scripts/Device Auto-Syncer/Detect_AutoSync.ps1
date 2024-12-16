<#
.SYNOPSIS
    Detection script to verify the last sync time of the PushLaunch scheduled task.

.DESCRIPTION
    This script checks the last synchronization time of the "PushLaunch" scheduled task.
    It ensures that the task was executed within the last 2 days. If the sync time exceeds
    2 days, the script flags it as needing remediation.

.EXAMPLE
    .\Detect_AutoSync.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-12-16
#>

# Retrieve information about the "PushLaunch" scheduled task
$PushInfo = Get-ScheduledTask -TaskName PushLaunch | Get-ScheduledTaskInfo

# Check if the task information exists
if ($PushInfo) {
    # Retrieve the LastRunTime of the task
    $LastPush = $PushInfo.LastRunTime | Select-Object -First 1
} else {
    Write-Host "Scheduled task 'PushLaunch' not found or no LastRunTime available."
    Exit 1  # Exit with an error code
}

# Get the current date/time
$CurrentTime = Get-Date

# Verify that the LastRunTime is valid
if ($LastPush -eq $null) {
    Write-Host "No valid LastRunTime found for PushLaunch task."
    Exit 1  # Exit with an error code
}

# Calculate the time difference between the last sync time and the current time
$TimeDiff = New-TimeSpan -Start $LastPush -End $CurrentTime

# Check if the time difference exceeds 2 days
if ($TimeDiff.Days -gt 2) {
    Write-Host "Last sync was more than 2 days ago."
    Exit 1  # Exit with an error code indicating failure
} else {
    Write-Host "Sync is up to date."
    Exit 0  # Exit with a success code
}
