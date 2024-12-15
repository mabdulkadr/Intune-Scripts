<#
.SYNOPSIS
    Detection Script to check for pending Windows updates.

.DESCRIPTION
    This script checks if there are any pending Windows updates on the system.
    It will return a message indicating whether updates are pending, excluding any firmware updates.

.EXAMPLE
    .\DetectPendingUpdates.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Function to check if a module is installed, and install it if not
function Ensure-Module {
    param (
        [string]$ModuleName
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Output "Module $ModuleName not found. Installing..."
        Install-Module -Name $ModuleName -Force -AllowClobber
    } else {
        Write-Output "Module $ModuleName is already installed."
    }
}

# Ensure PSWindowsUpdate module is installed
Ensure-Module -ModuleName "PSWindowsUpdate"

# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate

# Get the list of available updates
$Updates = Get-WindowsUpdate -ComputerName localhost -AcceptAll

# Check if there are any pending updates
if ($Updates.Count -gt 0) {
    Write-Output "There are $($Updates.Count) pending Windows Updates."
} else {
    Write-Output "No pending Windows Updates."
}

# This script only detects pending updates and does not install them.
