<#
.SYNOPSIS
    Checks if a system restart is required and saves the result to a file.

.DESCRIPTION
    This script checks if a system restart is required by looking at:
    - Pending Windows Updates
    - Pending file rename operations (only if non-empty)
    - Pending computer rename operations
    - Pending reboots due to software installations or Component-Based Servicing (CBS)

    The result is saved to a file in C:\Intune\RestartStatus.txt.

.NOTES
    Author  : M.omar
    Website : momar.tech
    Date    : 2024-09-15
    Version : 1.1
#>

# Ensure the C:\Intune directory exists
$intunePath = "C:\Intune"
if (-not (Test-Path $intunePath)) {
    New-Item -Path $intunePath -ItemType Directory -Force
}

# File to store the restart status
$statusFile = "$intunePath\RestartStatus.txt"

# Function to check if a restart is required
function Check-RestartRequired {

    # Check Windows Update pending reboot key
    $rebootRequiredWU = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired" -ErrorAction SilentlyContinue

    # Check if there are pending file rename operations (check if the key is not empty)
    $pendingFileRenameOperations = Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager" -Name "PendingFileRenameOperations" -ErrorAction SilentlyContinue
    $hasPendingFileRenameOperations = $pendingFileRenameOperations.PendingFileRenameOperations -and ($pendingFileRenameOperations.PendingFileRenameOperations.Count -gt 0)

    # Check if there's a pending computer rename by comparing ActiveComputerName and ComputerName
    $activeComputerName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ActiveComputerName").ComputerName
    $computerName = (Get-ItemProperty -Path "HKLM:\SYSTEM\CurrentControlSet\Control\ComputerName\ComputerName").ComputerName
    $pendingComputerRename = $activeComputerName -ne $computerName

    # Check if a reboot is pending for any other reasons (Component-Based Servicing)
    $componentBasedServicing = Get-ItemProperty -Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending" -ErrorAction SilentlyContinue

    # Determine if any condition requires a restart
    if ($rebootRequiredWU -or $hasPendingFileRenameOperations -or $pendingComputerRename -or $componentBasedServicing) {
        "Restart required" | Out-File -FilePath $statusFile -Encoding utf8
        Write-Output "Restart required"
        exit 1  # Exit with code 1 indicating a restart is needed
    } else {
        "No restart required" | Out-File -FilePath $statusFile -Encoding utf8
        Write-Output "No restart required"
        exit 0  # Exit with code 0 indicating no restart is needed
    }
}

# Run the check
Check-RestartRequired
