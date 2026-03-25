<#
.SYNOPSIS
    Custom Compliance Policy Detection Script for Intune.

.DESCRIPTION
    This script is designed to be used as a custom compliance policy in Microsoft Intune.
    It checks whether one or more applications are installed on the device and can also
    verify the installed version.

    It can work in two modes:
    1. Install check only:
       - Returns True/False for each application.
    2. Version check:
       - Returns the installed version.
       - If the application is not installed, returns 0.0.0.0.

    This output format is suitable for Microsoft Intune custom compliance policies.

    The related JSON configuration file can define:
    - The application name to check.
    - The required minimum version.
    - The compliance operator.
    - A URL with more information.
    - A custom remediation message.

    Make sure to enter the exact display name shown in Add or Remove Programs.

.EXAMPLE
    .\Check-App-Version.ps1

.NOTES
    Author  : Mohammad Abdelkader Omar
    Website : momar.tech
    Version : 1.1
#>

#region ---------- Configuration ----------

# Enter the exact display name as shown in Programs and Features
[array]$ApplicationNames = @(
    "Google Chrome"
)

# Set to $true to check user-based installs in HKCU instead of system-wide installs in HKLM
[bool]$UserProfileApp = $false

# Set to $true to return only True/False
# Set to $false to return the installed version instead
[bool]$IsAppInstallCheckOnly = $false

#endregion

#region ---------- Functions ----------

function Get-AppRegistryEntries {
    param (
        [bool]$CheckUserProfile
    )

    $Entries = @()

    if ($CheckUserProfile) {
        if (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall') {
            $Entries += Get-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
                Select-Object DisplayName, DisplayVersion
        }

        if (Test-Path 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall') {
            $Entries += Get-ItemProperty 'HKCU:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' -ErrorAction SilentlyContinue |
                Select-Object DisplayName, DisplayVersion
        }
    }
    else {
        $Entries = Get-ItemProperty `
            'HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall\*',
            'HKLM:\Software\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*' `
            -ErrorAction SilentlyContinue |
            Select-Object DisplayName, DisplayVersion
    }

    return $Entries
}

#endregion

#region ---------- Main ----------

$MyAppRegEntries = Get-AppRegistryEntries -CheckUserProfile $UserProfileApp
$CustomObject = @{}

foreach ($Application in $ApplicationNames) {
    $MatchedApp = $MyAppRegEntries |
        Where-Object { $_.DisplayName -eq $Application } |
        Select-Object -First 1

    if ($IsAppInstallCheckOnly) {
        $SettingName = "$Application Installed"
        $CustomObject[$SettingName] = [bool]($null -ne $MatchedApp)
    }
    else {
        if ($MatchedApp) {
            $CustomObject[$Application] = [string]$MatchedApp.DisplayVersion
        }
        else {
            $CustomObject[$Application] = '0.0.0.0'
        }
    }
}

return ($CustomObject | ConvertTo-Json -Compress)

#endregion