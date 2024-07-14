<#
.SYNOPSIS
    Detection Script to check for pending Windows updates using PSWindowsUpdate module, excluding firmware updates.

.DESCRIPTION
    This script uses the PSWindowsUpdate module to check for any pending updates on the system, excluding firmware updates.
    It exits with code 0 if no updates are pending and code 1 if updates are pending.

.EXAMPLE
    .\DetectPendingUpdates.ps1

.NOTES
    Author: M.omar
    Date: 2024-07-14
#>

# Check if running as an administrator
if (-not ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole] "Administrator")) {
    Write-Warning "You do not have Administrator rights to run this script!`nPlease re-run this script as an Administrator."
    exit 1
}

# Ensure PSWindowsUpdate module is installed
if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Write-Output "PSWindowsUpdate module is not installed. Installing..."
    Install-Module -Name PSWindowsUpdate -Force -Scope CurrentUser
    Import-Module PSWindowsUpdate
    Write-Output "PSWindowsUpdate module installed successfully."
} else {
    Import-Module PSWindowsUpdate
}

# Check for pending updates
try {
    $pendingUpdates = Get-WUList | Where-Object {$_.Status -ne "Installed" -and $_.Title -notmatch "firmware"}

    if ($pendingUpdates.Count -eq 0) {
        Write-Output "No updates pending."
        exit 0
    } else {
        Write-Output "Pending updates found."
        exit 1
    }
} catch {
    Write-Error "An error occurred while checking for updates: $_"
    exit 1
}
