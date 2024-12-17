<#
.SYNOPSIS
    Triggers Intune Management Extension sync and creates a scheduled task to ensure it runs hourly.

.DESCRIPTION
    This script triggers the IME sync using the Shell.Application COM object in a one-liner.
    It also creates a scheduled task to run the sync every hour to ensure consistent compliance.

.EXAMPLE
 .\Remediate_HourlyIMESync.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# Function to Trigger IME Sync
function Trigger-IMESync {
    try {
        Write-Output "Triggering Intune Management Extension Sync..."
        (New-Object -ComObject Shell.Application).Open("intunemanagementextension://syncapp")
        Write-Output "Intune Management Extension Sync triggered successfully."
    }
    catch {
        Write-Error "Failed to trigger IME sync: $_"
        exit 1
    }
}

# Function to Trigger IME Sync
function Trigger-IMESync {
    try {
        Write-Output "Triggering Intune Management Extension Sync..."
        $Shell = New-Object -ComObject Shell.Application
        $Shell.Open("intunemanagementextension://syncapp")
        Write-Output "Intune Management Extension Sync triggered successfully."
    }
    catch {
        Write-Error "Failed to trigger IME sync: $_"
        exit 1
    }
}

# Function to Create Scheduled Task for IME Sync
function Create-IMESyncScheduledTask {
    $TaskName = "Trigger-IME-Sync-Hourly"
    $TaskDescription = "Scheduled task to trigger Intune Management Extension Sync every hour."
    $TaskAction = "PowerShell.exe"
    $TaskArgument = "-NoProfile -WindowStyle Hidden -Command `"(New-Object -ComObject Shell.Application).Open('intunemanagementextension://syncapp')`""

    try {
        Write-Output "Creating a scheduled task to trigger IME sync every hour..."

        # Define Task Action
        $Action = New-ScheduledTaskAction -Execute $TaskAction -Argument $TaskArgument

        # Define Trigger: Starts 1 minute from now and repeats every hour
        $Trigger = New-ScheduledTaskTrigger -Once -At (Get-Date).AddMinutes(1) -RepetitionInterval (New-TimeSpan -Hours 1)

        # Register the Task
        Register-ScheduledTask -TaskName $TaskName -Description $TaskDescription -Action $Action -Trigger $Trigger -User "SYSTEM" -RunLevel Highest -Force

        Write-Output "Scheduled task '$TaskName' created successfully."
    }
    catch {
        Write-Error "Failed to create scheduled task: $_"
        exit 1
    }
}

# Main Execution
Write-Output "Starting remediation process for Intune Management Extension Sync..."

# Trigger IME Sync Immediately
Trigger-IMESync

# Create Scheduled Task for Hourly Sync
Create-IMESyncScheduledTask

Write-Output "Remediation process completed successfully."
exit 0
