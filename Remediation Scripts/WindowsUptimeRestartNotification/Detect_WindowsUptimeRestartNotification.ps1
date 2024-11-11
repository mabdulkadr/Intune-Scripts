<#
.SYNOPSIS
    Checks the device uptime and exits with a code indicating if a reboot is recommended.

.DESCRIPTION
    This script evaluates the device's uptime in days. If the system has not been rebooted for 7 days or more, it exits with code 1, indicating that a reboot is recommended. Otherwise, it exits with code 0.

.RUN AS
    User

.EXAMPLE
    .\Detect_WindowsUptimeRestartNotification.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-11

#>

$Uptime= get-computerinfo | Select-Object OSUptime 
if ($Uptime.OsUptime.Days -ge 7){
    Write-Output "Device has not rebootet on $($Uptime.OsUptime.Days) days, notify user to reboot"
    Exit 1
}else {
    Write-Output "Device has rebootet $($Uptime.OsUptime.Days) days ago, all good"
    Exit 0
}
