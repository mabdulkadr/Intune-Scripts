<#
Script: Detect_WindowsUptimeRestartNotification.ps1
Description: Checks the device uptime days. If its 7 days or more it shows a windows notification to the user that he should reboot.
Hint: This is a community script. There is no guarantee for this. Please check thoroughly before running.
#> 

$Uptime= get-computerinfo | Select-Object OSUptime 
if ($Uptime.OsUptime.Days -ge 7){
    Write-Output "Device has not rebootet on $($Uptime.OsUptime.Days) days, notify user to reboot"
    Exit 1
}else {
    Write-Output "Device has rebootet $($Uptime.OsUptime.Days) days ago, all good"
    Exit 0
}