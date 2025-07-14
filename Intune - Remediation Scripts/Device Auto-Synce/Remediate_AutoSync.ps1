<#
.SYNOPSIS
    Remediation script to force Intune device synchronization.

.DESCRIPTION
    This script addresses synchronization issues for Intune-enrolled devices by ensuring that the "PushLaunch" scheduled task
    is executed. If the task does not exist, it creates the task to guarantee that the device synchronizes with Intune policies.

.EXAMPLE
    .\Remediate_AutoSync.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-12-16
#>

try {
    # Attempt to start the "PushLaunch" scheduled task
    Get-ScheduledTask | Where-Object { $_.TaskName -eq 'PushLaunch' } | Start-ScheduledTask
    Write-Host "The 'PushLaunch' task has been started successfully."
    Exit 0  # Exit with a success code
} catch {
    # Handle errors by logging the error message and exiting with an error code
    Write-Error "Failed to start the 'PushLaunch' task: $_"
    Exit 1  # Exit with a failure code
}
