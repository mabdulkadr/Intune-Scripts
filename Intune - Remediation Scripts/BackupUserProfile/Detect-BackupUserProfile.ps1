<#
.SYNOPSIS
    Script to check if a backup operation has already been run within the past hour.

.DESCRIPTION
    This script verifies the last backup timestamp recorded in a file (backup.txt) and determines whether another backup
    operation is needed. It compares the current time against the timestamp in the file to ensure that backups are not
    repeated within an hour.

.EXAMPLE
    Detect-BackupUserProfile.ps1

    This will check the backup status and output whether the backup should run again or has already been run this hour.

.NOTES
    Author: [Your Name]
    Website: [Your Website or Relevant Link]
    Date: [Creation/Modification Date]
#>

# Define constants
$todaysdate = Get-Date -Format "dd-MM-yyyy-HH" # Get the current date in the specified format
$dir = Join-Path $env:APPDATA "backup-restore" # Path to the backup directory
$backupfile = Join-Path $dir "backup.txt" # Full path to the backup file

# Check if the backup directory exists
if (-not (Test-Path -Path $dir)) {
    Write-Warning "The backup directory does not exist: $dir"
    exit 1
}

# Check if the backup file exists
if (-not (Test-Path -Path $backupfile)) {
    Write-Warning "The backup file does not exist: $backupfile"
    exit 1
}

# Retrieve the backup date from the file
try {
    $backupdate = Get-Content -Path $backupfile -ErrorAction Stop
    $checkdate = Get-Date -Date $backupdate -Format "dd-MM-yyyy-HH"
} catch {
    Write-Error "Failed to read or parse the backup file: $_"
    exit 1
}

# Compare the backup timestamp with the current timestamp
if ($checkdate -lt $todaysdate) {
    Write-Host "Backup should run again." -ForegroundColor Green
    exit 1
} else {
    Write-Host "Backup already run this hour." -ForegroundColor Yellow
    exit 0
}
