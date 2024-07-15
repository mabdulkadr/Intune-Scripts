<#
.SYNOPSIS
    This script detects all installed versions of Mozilla Firefox on a machine and checks for the existence of specific Firefox-related directories.

.DESCRIPTION
    The script performs the following actions:
    1. Searches the Windows registry for installed versions of Mozilla Firefox.
    2. Outputs a list of installed versions along with their details.
    3. Logs the detection process and results to a specified log file.
    4. Checks for the existence of remaining Firefox directories, including "C:\Program Files (x86)\Mozilla Firefox" and "C:\Program Files (x86)\Mozilla Maintenance Service".

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-11
    Version: 1.0
#>

# Define log file path
$logFilePath = "C:\Intune\FirefoxDetectionLog.txt"

# Function to log messages to a file
function Log-Message {
    param (
        [string]$message
    )
    Write-Output $message | Out-File -FilePath $logFilePath -Append
    Write-Output $message
}

# Function to get installed versions of Mozilla Firefox
function Get-FirefoxInstalledVersions {
    $installedVersions = @()
    $registryPaths = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall",
        "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall"
    )

    foreach ($path in $registryPaths) {
        $installedApps = Get-ChildItem -Path $path -ErrorAction SilentlyContinue | ForEach-Object {
            Get-ItemProperty -Path $_.PSPath -ErrorAction SilentlyContinue
        }

        foreach ($app in $installedApps) {
            if ($app.DisplayName -like "Mozilla Firefox*") {
                $installedVersions += New-Object PSObject -Property @{
                    DisplayName = $app.DisplayName
                    DisplayVersion = $app.DisplayVersion
                    Publisher = $app.Publisher
                    UninstallString = $app.UninstallString
                }
            }
        }
    }

    return $installedVersions
}

# Get the installed versions of Mozilla Firefox
$installedVersions = Get-FirefoxInstalledVersions

if ($installedVersions.Count -gt 0) {
    foreach ($version in $installedVersions) {
        Log-Message "Detected Mozilla Firefox:"
        Log-Message "  DisplayName: $($version.DisplayName)"
        Log-Message "  DisplayVersion: $($version.DisplayVersion)"
        Log-Message "  Publisher: $($version.Publisher)"
        Log-Message "  UninstallString: $($version.UninstallString)"
    }
} else {
    Log-Message "No installed versions of Mozilla Firefox were found on this machine."
}

# Check for existence of remaining Firefox directories
$firefoxDirs = @(
    "$env:ProgramFiles\Mozilla Firefox",
    "$env:ProgramFiles(x86)\Mozilla Firefox",
    "$env:ProgramFiles\Mozilla Maintenance Service",
    "$env:ProgramFiles(x86)\Mozilla Maintenance Service"
)

foreach ($dir in $firefoxDirs) {
    if (Test-Path $dir) {
        Log-Message "Remaining directory found: $dir"
    }
}
