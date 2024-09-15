<#
.SYNOPSIS
    This script checks if a device requires a restart.

.DESCRIPTION
    The script checks the system's current status to determine if a restart is necessary.
    It does this by:
    1. Checking if there are any pending Windows Updates that require a restart.
    2. Checking the registry for pending file rename operations that typically require a restart.
    If any of these conditions are true, it outputs a value indicating that a restart is required.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-09-15
    Version : 1.0
#>

function Check-RestartRequired {
    # Check if there is a pending reboot due to Windows Updates using WMI
    $wmiOS = Get-CimInstance -ClassName Win32_OperatingSystem
    $pendingReboot = $wmiOS.PSComputerName -and $wmiOS.RebootPending

    # Check if there are pending file rename operations (typically set by software installations)
    $pendingFileRename = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" `
        -Name PendingFileRenameOperations -ErrorAction SilentlyContinue).PendingFileRenameOperations

    # If a pending reboot or file rename is found, output 1 (restart required)
    if ($pendingReboot -or $pendingFileRename) {
        Write-Output 1
    } else {
        # Output 0 if no restart is required
        Write-Output 0
    }
}

# Execute the function to check if a restart is required
Check-RestartRequired
