<#
.SYNOPSIS
    Comprehensive script to troubleshoot, repair, and reset Windows Update components.
    It checks OS versions, registry configurations, and ensures all Windows update services and modules are functioning properly.

.DESCRIPTION
    This script automates the following tasks:
    1. Runs Windows Update troubleshooter.
    2. Repairs the Windows image using DISM.
    3. Removes paused or deferred update registry keys.
    4. Installs necessary PowerShell modules (FU.WhyAmIBlocked, PSWindowsUpdate, NuGet).
    5. Checks for feature update blocks.
    6. Resets Windows Update components.
    7. Installs pending Windows updates.
    8. Logs all activities for monitoring.

.EXAMPLE
    Run the script in PowerShell:
    .\WindowsUpdate-Troubleshoot.ps1


.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-12-17
    
    Logs: Saved in C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\
#>

# Variables for Windows Versions
$CurrentWin10 = "10.0.19045"  # Latest Windows 10 build
$CurrentWin11 = "10.0.22631"  # Latest Windows 11 build

# Start Transcript Logging
$LogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#Windows_Updates_Health_Check.log"
Start-Transcript -Path $LogPath -Append

# Run Windows Update Troubleshooter
Write-Output "[INFO] Running Windows Update Troubleshooter..."
try {
    Get-TroubleshootingPack -Path C:\Windows\diagnostics\system\WindowsUpdate |
        Invoke-TroubleshootingPack -Unattended
} catch {
    Write-Warning "[ERROR] Failed to run Windows Update troubleshooter: $_"
}

# Run DISM to Repair System Image
Write-Output "[INFO] Running DISM for system image repair..."
$DISMLogPath = "C:\ProgramData\Microsoft\IntuneManagementExtension\Logs\#DISM.log"
try {
    Repair-WindowsImage -RestoreHealth -NoRestart -Online -LogPath $DISMLogPath -Verbose
} catch {
    Write-Warning "[ERROR] DISM operation failed: $_"
}

# Registry Paths for Windows Updates
$RegPaths = @{
    UpdatePolicy     = "HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings"
    DeviceUpdate     = "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update"
    DataCollection   = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection"
    Appraiser        = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\AppCompatFlags\Appraiser\GWX"
    WindowsUpdate    = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate"
}

# Function to Remove Registry Keys and Properties
function Reset-RegistryKeys {
    param (
        [string]$Path, [string[]]$PropertiesToRemove
    )
    if (Test-Path $Path) {
        Write-Output "[INFO] Resetting registry keys at: $Path"
        foreach ($Property in $PropertiesToRemove) {
            if ((Get-Item $Path).Property -contains $Property) {
                Write-Output "[INFO] Removing property: $Property"
                Remove-ItemProperty -Path $Path -Name $Property -Verbose
            }
        }
    }
}

# Clean Update-Related Registry Keys
Reset-RegistryKeys -Path $RegPaths.UpdatePolicy -PropertiesToRemove @("PausedQualityDate", "PausedFeatureDate", "PausedQualityStatus", "PausedFeatureStatus")
Reset-RegistryKeys -Path $RegPaths.DeviceUpdate -PropertiesToRemove @("PauseQualityUpdatesStartTime", "PauseFeatureUpdatesStartTime", "DeferFeatureUpdatesPeriodInDays")

# Install Required Modules
function Install-RequiredModule {
    param (
        [string]$ModuleName
    )
    if (-not (Get-InstalledModule -Name $ModuleName -ErrorAction SilentlyContinue)) {
        Write-Output "[INFO] Installing module: $ModuleName"
        Install-Module -Name $ModuleName -Force -Verbose
    } else {
        Write-Output "[INFO] Module $ModuleName already installed."
    }
}

Write-Output "[INFO] Checking and installing required PowerShell modules..."
Install-RequiredModule -ModuleName "PSWindowsUpdate"
Install-RequiredModule -ModuleName "FU.WhyAmIBlocked"

# Reset Windows Update Components
Write-Output "[INFO] Resetting Windows Update components..."
try {
    Reset-WUComponents -Verbose
} catch {
    Write-Warning "[ERROR] Failed to reset Windows Update components: $_"
}

# Check for Windows Updates
Write-Output "[INFO] Checking for pending Windows updates..."
try {
    Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot -Verbose
} catch {
    Write-Warning "[ERROR] Failed to check for Windows updates: $_"
}

Stop-Transcript
Write-Output "[INFO] Script execution completed. Log saved at $LogPath"
