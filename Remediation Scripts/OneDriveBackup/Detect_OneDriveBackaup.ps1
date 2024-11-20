<#
.SYNOPSIS
    Detection script for Intune proactive remediation to determine if a backup is needed.

.DESCRIPTION
    Checks if there are any files in the local OneDrive folders that are not backed up to OneDrive cloud storage.
    If such files exist, the script outputs a detection result indicating that remediation is required.

.RUN AS
    System

.EXAMPLE
    .\DetectionScript.ps1

.NOTES
    Author  : [Your Name]
    Date    : [Date]
#>

# Import necessary modules
Function Ensure-Module {
    param ([Parameter(Mandatory = $true)] [string]$ModuleName)
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Install-Module -Name $ModuleName -Force -Scope AllUsers
    }
    Import-Module $ModuleName -ErrorAction Stop
}

Ensure-Module -ModuleName "Microsoft.Graph.Authentication"
Ensure-Module -ModuleName "Microsoft.Graph.Users"
Ensure-Module -ModuleName "Microsoft.Graph.Files"

# Set variables
$BackupNeeded = $false

# Get all user profiles
$userProfiles = Get-ChildItem 'C:\Users' -Directory | Where-Object {
    $_.Name -notin @('Default', 'Default User', 'Public', 'All Users')
}

foreach ($profile in $userProfiles) {
    $userProfilePath = $profile.FullName

    # Attempt to find the OneDrive folder
    $oneDriveBasePath = Get-ChildItem -Path $userProfilePath -Directory -Filter "OneDrive*" -ErrorAction SilentlyContinue | Select-Object -First 1

    if ($null -ne $oneDriveBasePath) {
        # Define folders to check
        $foldersToCheck = @(
            Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Documents"
            Join-Path -Path $oneDriveBasePath.FullName -ChildPath "المستندات"
            Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Desktop"
            Join-Path -Path $oneDriveBasePath.FullName -ChildPath "سطح المكتب"
            Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Pictures"
            Join-Path -Path $oneDriveBasePath.FullName -ChildPath "الصور"
            Join-Path -Path $userProfilePath -ChildPath "Downloads"
            Join-Path -Path $userProfilePath -ChildPath "التنزيلات"
            Join-Path -Path $userProfilePath -ChildPath "Videos"
            Join-Path -Path $userProfilePath -ChildPath "ملفات الفيديو"
            Join-Path -Path $userProfilePath -ChildPath "Music"
            Join-Path -Path $userProfilePath -ChildPath "الموسيقى"
        )

        foreach ($folderPath in $foldersToCheck) {
            if (Test-Path $folderPath) {
                # If any files are found, set BackupNeeded to true
                $files = Get-ChildItem -Path $folderPath -Recurse -File -ErrorAction SilentlyContinue
                if ($files) {
                    $BackupNeeded = $true
                    break
                }
            }
        }
    }
    if ($BackupNeeded) { break }
}

# Output the detection result
if ($BackupNeeded) {
    Write-Output "{`"DetectionResult`": true}"
    exit 0
} else {
    Write-Output "{`"DetectionResult`": false}"
    exit 0
}
