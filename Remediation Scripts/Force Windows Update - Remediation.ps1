<#
.SYNOPSIS
    Remediation Script to download and install pending Windows updates using PSWindowsUpdate module, excluding firmware updates.

.DESCRIPTION
    This script uses the PSWindowsUpdate module to search for, download, and install any pending updates on the system, excluding firmware updates.
    It requires administrative privileges to run and will output the progress of the update process.

.EXAMPLE
    .\RemediatePendingUpdates.ps1

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

# Search for updates
try {
    Write-Output "Searching for updates..."
    $pendingUpdates = Get-WUList | Where-Object {$_.Status -ne "Installed" -and $_.Title -notmatch "firmware"}

    # Check if there are updates available
    if ($pendingUpdates.Count -eq 0) {
        Write-Output "No updates available."
        exit 0
    } else {
        Write-Output "$($pendingUpdates.Count) updates found."
    }

    # Download and install updates
    Write-Output "Downloading and installing updates..."
    Install-WindowsUpdate -AcceptAll -AutoReboot -IgnoreReboot

    Write-Output "Windows Update completed."
    exit 0
} catch {
    Write-Error "An error occurred during the update process: $_"
    exit 1
}
