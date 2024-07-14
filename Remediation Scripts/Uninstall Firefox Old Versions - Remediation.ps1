<#
.SYNOPSIS
    This script silently uninstalls all installed versions of Mozilla Firefox from a machine and removes any remaining Firefox-related files and directories.

.DESCRIPTION
    The script performs the following actions:
    1. Searches the Windows registry for uninstall strings of all installed versions of Mozilla Firefox.
    2. Silently uninstalls each detected version of Mozilla Firefox using the uninstall string.
    3. Removes any remaining Firefox-related files and directories from the system.
    4. Logs the progress and any errors encountered during the process to a specified log file.

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-11
    Version: 1.0
#>


# Define log file path
$logFilePath = "C:\Intune\FirefoxRemediationLog.txt"

# Function to log messages to a file
function Log-Message {
    param (
        [string]$message
    )
    Write-Output $message | Out-File -FilePath $logFilePath -Append
    Write-Output $message
}

# Function to get uninstall strings for Mozilla Firefox
function Get-FirefoxUninstallStrings {
    $uninstallStrings = @()
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
                $uninstallStrings += $app.UninstallString
            }
        }
    }

    return $uninstallStrings
}

# Function to remove Firefox-related files and directories
function Remove-FirefoxFiles {
    $firefoxDirs = @(
        "$env:ProgramFiles\Mozilla Firefox",
        "$env:ProgramFiles(x86)\Mozilla Firefox",
        "$env:APPDATA\Mozilla",
        "$env:LOCALAPPDATA\Mozilla"
    )

    foreach ($dir in $firefoxDirs) {
        if (Test-Path $dir) {
            Remove-Item -Recurse -Force $dir -ErrorAction SilentlyContinue
            Log-Message "Removed directory: $dir"
        }
    }
}

# Get the uninstall strings for all installed Firefox versions
$uninstallStrings = Get-FirefoxUninstallStrings

if ($uninstallStrings.Count -gt 0) {
    foreach ($uninstallString in $uninstallStrings) {
        try {
            if ($uninstallString) {
                Log-Message "Attempting to uninstall Mozilla Firefox using command: $uninstallString"

                # Extract the uninstall command and arguments
                if ($uninstallString -match '^(.*?\.exe)\s*(.*)$') {
                    $uninstallCommand = $matches[1]
                    $uninstallArgs = $matches[2] + ' /S'
                } else {
                    $uninstallCommand = $uninstallString
                    $uninstallArgs = '/S'
                }

                Log-Message "Uninstall command: $uninstallCommand"
                Log-Message "Uninstall arguments: $uninstallArgs"

                # Check if the uninstall command file exists
                if (-Not (Test-Path $uninstallCommand)) {
                    Log-Message "Uninstall command file not found: $uninstallCommand"
                    continue
                }

                # Execute the uninstall command using Start-Process
                Log-Message "Executing uninstall command..."
                Start-Process -FilePath $uninstallCommand -ArgumentList $uninstallArgs -NoNewWindow -Wait -ErrorAction Stop

                # Verify uninstallation
                Start-Sleep -Seconds 30  # Wait for uninstallation to complete
                $remainingUninstallStrings = Get-FirefoxUninstallStrings
                if ($remainingUninstallStrings.Count -eq 0) {
                    Log-Message "Mozilla Firefox has been successfully uninstalled."
                } else {
                    Log-Message "Failed to uninstall Mozilla Firefox."
                }
            } else {
                Log-Message "Uninstall string is empty or null."
            }
        } catch {
            Log-Message "Error while trying to uninstall Mozilla Firefox: $_"
        }
    }

    # Remove remaining Firefox-related files and directories
    Remove-FirefoxFiles
} else {
    Log-Message "No installed versions of Mozilla Firefox were found on this machine."
}

