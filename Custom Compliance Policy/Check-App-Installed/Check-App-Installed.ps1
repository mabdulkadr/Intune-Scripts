<#
.SYNOPSIS
    Custom compliance policy script for Intune to check if specific applications are installed on enrolled devices.

.DESCRIPTION
    This script is designed for use with Intune custom compliance policies.
    It checks whether specified applications are installed on a Windows device by verifying both traditional Win32 applications and Microsoft Store apps.
    The output is returned as a JSON object, which Intune can use to determine compliance status.

.EXAMPLE
    ```powershell
    .\Check-App-IsInstalled.ps1
    ```
    This will return a JSON object indicating the installation status of the specified applications.

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# List of applications to check for installation
[array]$applicationName = @("Microsoft.CompanyPortal")  # Example: "Google Chrome", "7-Zip", "Mozilla Firefox", "Zoom"

# DO NOT EDIT THE LINES BELOW
# Initialize an array to store application info
$appInstalled = $false

# Function to check if an Appx package is installed
function Get-AppxPackageInfo {
    param (
        [string]$appName
    )
    $appxPackage = Get-AppxPackage -Name $appName -ErrorAction SilentlyContinue
    return [bool]$appxPackage
}

# Retrieve installed programs from registry
[array]$myAppRegEntries = Get-ItemProperty 'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*','HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue | Select-Object DisplayName

# Loop through each application name specified
foreach ($application in $applicationName) {
    # Check if the app exists in registry entries
    foreach ($myAppReg in $myAppRegEntries) {
        if ($myAppReg.DisplayName -eq $application) {
            $appInstalled = $true
            break
        }
    }

    # Check if the app is an Appx package if not found in registry
    if (-not $appInstalled) {
        $appInstalled = Get-AppxPackageInfo -appName $application
    }
}

# Convert the output to the required JSON format
$objectJSONoutput = @{ Installed = $appInstalled } | ConvertTo-Json -Compress

# Return output
return $objectJSONoutput
