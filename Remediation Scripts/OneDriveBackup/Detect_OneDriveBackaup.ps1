<#
.SYNOPSIS
    Detection script for Intune proactive remediation to check if a folder with today's date exists.

.DESCRIPTION
    This script checks if a folder with the current date (formatted as yyyy-MM-dd) exists at the specified OneDrive backup path.

.EXAMPLE
    .\Detect_OneDriveBackaup.ps1

.NOTES
    Author  : Mohammad Abdulkader Omar
    Website : momar.tech
    Date    : 2024-11-04
#>

# ============================
#        VARIABLES
# ============================

# Backup Configuration
$BackupFolderName = "OneDriveBackups"               # Name of the backup folder in OneDrive
$BackupDateFormat = "yyyy-MM-dd"                    # Date format for backup folders

# OneDrive Path Configuration
$OneDriveFolderName = "OneDrive - Your Organization"  # Replace with your OneDrive folder name

# ============================
#        DETECTION LOGIC
# ============================

# Define the base path where the backup folders are stored
$basePath = "C:\Users\$env:USERNAME\$OneDriveFolderName\$BackupFolderName"

# Get today's date in the format yyyy-MM-dd
$todayDate = (Get-Date).ToString($BackupDateFormat)

# Create the full path for the folder with today's date
$todayFolderPath = Join-Path -Path $basePath -ChildPath $todayDate

# Check if the folder with today's date exists
if (Test-Path -Path $todayFolderPath) {
    Write-Host "Folder with today's date ($todayDate) found at $todayFolderPath."
    exit 0  # Return 0 if the folder exists (compliant)
} else {
    Write-Host "Folder with today's date ($todayDate) not found at $todayFolderPath."
    exit 1  # Return 1 if the folder does not exist (non-compliant)
}
