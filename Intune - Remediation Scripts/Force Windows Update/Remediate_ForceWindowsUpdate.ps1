<#
.SYNOPSIS
    Remediation Script to force the installation of pending Windows updates.

.DESCRIPTION
    This script forces the installation of all pending Windows updates on the local system.
    It will reboot the system if necessary after the updates are installed.

.EXAMPLE
    .\InstallPendingUpdates.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

#----------------------------- Set execution policy -----------------------------  

# Check the current execution policy                                          
$currentPolicy = Get-ExecutionPolicy

# If the execution policy is not 'Restricted', change it to 'Unrestricted'
if ($currentPolicy -ne 'Restricted') {
    Write-Host "Current Execution Policy is: $currentPolicy. Changing to Unrestricted..." -ForegroundColor Yellow
    # Set the execution policy to 'Unrestricted'
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Force
    Write-Host "Execution Policy changed to Unrestricted." -ForegroundColor Green
} else {
    Write-Host "Current Execution Policy is Restricted. No changes made." -ForegroundColor Cyan
}

#----------------------------- Ensure Module -----------------------------  

# Function to check if a module is installed, and install it if not
function Ensure-Module {
    param (
        [string]$ModuleName
    )

    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Module $ModuleName not found. Installing..." -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Force -AllowClobber
    } else {
        Write-Host "Module $ModuleName is already installed." -ForegroundColor Green
    }
}

#----------------------------- Pending Reboot Check -----------------------------  

# Function to check for a pending reboot
function Test-PendingReboot {
    $PendingRebootKeys = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending",
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations"
    )
    
    foreach ($Key in $PendingRebootKeys) {
        if (Test-Path $Key) {
            return $true
        }
    }
    return $false
}

#----------------------------- Windows Updates -----------------------------  

# Ensure PSWindowsUpdate module is installed
Ensure-Module -ModuleName "PSWindowsUpdate"

# Import the PSWindowsUpdate module
Import-Module PSWindowsUpdate -ErrorAction Stop

# Get the list of available updates
$Updates = Get-WindowsUpdate -AcceptAll -IgnoreReboot

if ($Updates.Count -gt 0) {
    Write-Host "Installing $($Updates.Count) pending Windows updates..." -ForegroundColor Cyan
    Install-WindowsUpdate -AcceptAll -IgnoreReboot -Verbose
    Write-Host "All pending updates installed successfully." -ForegroundColor Green

    # Check if a reboot is required
    if (Test-PendingReboot) {
        Write-Host "A reboot is required to complete the update process." -ForegroundColor Yellow
    } else {
        Write-Host "No reboot is required after updates." -ForegroundColor Green
    }
} else {
    Write-Host "No pending updates found." -ForegroundColor Green
}
