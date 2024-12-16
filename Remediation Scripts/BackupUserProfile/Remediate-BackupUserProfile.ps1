<#
.SYNOPSIS
    Runs a backup script on user login.

.DESCRIPTION
    This script sets up a scheduled task that triggers a backup of all key user data to OneDrive upon user login. 
    It downloads the necessary backup, restore, and silent launch scripts and stores them in a designated folder.

.EXAMPLE
    Remediate-BackupUserProfile.ps1

    This will create the necessary directory, download required scripts, and set up a scheduled task to back up user profiles.

.NOTES
    Author: [Your Name]
    Website: [Your Website or Relevant Link]
    Date: [Creation/Modification Date]
#>

# Variables
$DirectoryToCreate = "C:\backup-restore"
$BackupScriptUrl = "https://raw.githubusercontent.com/mabdulkadr/Intune/refs/heads/main/Remediation%20Scripts/BackupUserProfile/backup.bat"
$RestoreScriptUrl = "https://raw.githubusercontent.com/mabdulkadr/Intune/refs/heads/main/Remediation%20Scripts/BackupUserProfile/NEWrestore.bat"
$LaunchScriptUrl = "https://raw.githubusercontent.com/mabdulkadr/Intune/refs/heads/main/Remediation%20Scripts/BackupUserProfile/run-invisible.vbs"
$BackupScriptPath = Join-Path $DirectoryToCreate "backup.bat"
$RestoreScriptPath = Join-Path $DirectoryToCreate "restore.bat"
$LaunchScriptPath = Join-Path $DirectoryToCreate "run-invisible.vbs"
$TaskName = "UserBackup"
$Description = "Backs up User profile to OneDrive"

# Ensure the directory exists
if (-not (Test-Path -LiteralPath $DirectoryToCreate)) {
    try {
        New-Item -Path $DirectoryToCreate -ItemType Directory -ErrorAction Stop | Out-Null
        Write-Host "Successfully created directory: '$DirectoryToCreate'" -ForegroundColor Green
    } catch {
        Write-Error "Unable to create directory '$DirectoryToCreate'. Error: $_"
        exit 1
    }
} else {
    Write-Host "Directory already exists: '$DirectoryToCreate'" -ForegroundColor Yellow
}

# Function to download scripts
function Download-Script {
    param (
        [Parameter(Mandatory = $true)]
        [string]$Url,

        [Parameter(Mandatory = $true)]
        [string]$Destination
    )
    try {
        Invoke-WebRequest -Uri $Url -OutFile $Destination -UseBasicParsing -ErrorAction Stop
        Write-Host "Successfully downloaded: '$Url' to '$Destination'" -ForegroundColor Green
    } catch {
        Write-Error "Failed to download from '$Url'. Error: $_"
        exit 1
    }
}

# Download required scripts
Download-Script -Url $BackupScriptUrl -Destination $BackupScriptPath
Download-Script -Url $RestoreScriptUrl -Destination $RestoreScriptPath
Download-Script -Url $LaunchScriptUrl -Destination $LaunchScriptPath

# Create a new task action
$TaskAction = New-ScheduledTaskAction -Execute $LaunchScriptPath

# Create a logon trigger
$LogonTrigger = New-ScheduledTaskTrigger -AtLogOn
$DailyTrigger = New-ScheduledTaskTrigger -Daily -At "1:00AM"

# Register the scheduled task
try {
    Register-ScheduledTask -TaskName $TaskName -Action $TaskAction -Trigger @($LogonTrigger, $DailyTrigger) -Description $Description -Force -ErrorAction Stop
    Write-Host "Successfully registered scheduled task: '$TaskName'" -ForegroundColor Green
} catch {
    Write-Error "Failed to register scheduled task. Error: $_"
    exit 1
}
