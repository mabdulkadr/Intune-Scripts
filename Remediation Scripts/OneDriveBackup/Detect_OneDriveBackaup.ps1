<#
.SYNOPSIS
    Detection script for Intune proactive remediation to check if a folder with today's date exists.

.DESCRIPTION
    This script checks if a folder with the current date (formatted as yyyy-MM-dd) exists at the specified OneDrive backup path.

.EXAMPLE
    .\Detect_OneDriveBackup.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-12
#>

# ============================
#        VARIABLES
# ============================

# Backup Configuration
$BackupFolderName         = "OneDriveBackups"                # Name of the backup folder in OneDrive
$BackupDateFormat         = "yyyy-MM-dd"                     # Date format for backup folders

# ============================
#        DETECTION LOGIC
# ============================

# Automatically detect the OneDrive path using the OneDrive environment variable
$OneDrivePath = [System.Environment]::GetEnvironmentVariable("OneDrive")

# Check if OneDrive path is found
if (-not $OneDrivePath) {
    Write-Host "OneDrive path not found for the user."
    exit 1  # Exit with non-compliance if OneDrive is not set up
}

# Define the backup folder path
$basePath = Join-Path -Path $OneDrivePath -ChildPath $BackupFolderName

# Get today's date in the format yyyy-MM-dd
$todayDate = (Get-Date).ToString($BackupDateFormat)

# Create the full path for the folder with today's date
$todayFolderPath = Join-Path -Path $basePath -ChildPath $todayDate

# Check if the folder with today's date exists
if (Test-Path -Path $todayFolderPath) {
    Write-Host "Folder with today's date ($todayDate) found at $todayFolderPath." -ForegroundColor Green
    exit 0  # Return 0 if the folder exists (compliant)
} else {
    Write-Host "Folder with today's date ($todayDate) not found at $todayFolderPath." -ForegroundColor Red
    exit 1  # Return 1 if the folder does not exist (non-compliant)
}
