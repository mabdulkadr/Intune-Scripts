<#
.SYNOPSIS
    Remediation Script to force the installation of pending Windows updates.

.DESCRIPTION
    This script forces the installation of all pending Windows updates on the system.
    It will reboot the system if necessary after the updates are installed.

.EXAMPLE
    .\InstallPendingUpdates.ps1

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
$Updates = Get-WindowsUpdate -ComputerName localhost -AcceptAll -Install -Silent -Verbose

# Check if there are any pending updates

    # Install all pending updates
    Write-Output "Installing $($Updates.Count) pending Windows Updates..."
    Install-WindowsUpdate -AcceptAll
    

# This script installs all pending updates and may require a reboot.
