<#
.SYNOPSIS
    Detection Script to check if Winget is installed and working.

.DESCRIPTION
    This script checks if the Winget executable exists and is functioning properly.
    It will return a zero exit code if Winget is detected and working correctly.
    If Winget is not installed or not working, it will return a non-zero exit code and log the status.

.EXAMPLE
    .\DetectWinget.ps1

.NOTES
    Author: M.omar
    Website: momar.tech
    Date: 2024-07-14
#>

# Create folders for logging
if (!(Test-Path "C:\Intune\Winget")) {
    New-Item -ItemType directory -Path "C:\Intune\Winget" -ErrorAction SilentlyContinue
}

# Log file path
$logPath = "C:\Intune\Winget\DetectWinget.log"

# Function to log messages with timestamps
function Log-Message {
    param (
        [string]$message,
        [string]$color = "White"
    )
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    Write-Host "$timestamp - $message" -ForegroundColor $color
    $timestamp + " - " + $message | Out-File -FilePath $logPath -Append
}

# Detection Script
try {
    $wingetPath = Get-Command winget -ErrorAction SilentlyContinue
    if ($null -eq $wingetPath) {
        Log-Message "Winget is not installed." "Red"
        Write-Output "Not Detected"
        exit 1
    } else {
        $wingetVersion = & winget --version
        if ($wingetVersion) {
            Log-Message "Winget is installed and working. Version: $wingetVersion" "Green"
            Write-Output "Detected"
            exit 0
        } else {
            Log-Message "Winget is installed but not working properly." "Red"
            Write-Output "Not Detected"
            exit 1
        }
    }
} catch {
    Log-Message "Error checking Winget: $_" "Red"
    Write-Output "Not Detected"
    exit 1
}
