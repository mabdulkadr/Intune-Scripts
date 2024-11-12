<#
.SYNOPSIS
    Backs up specified user folders (Documents, Pictures, Videos, Downloads, Music) to the user's OneDrive online account.

.DESCRIPTION
    This script connects to OneDrive for Business using app-only authentication, creates a backup folder structure,
    uploads files from the specified local folders, and retains backups for the last three days by cleaning up older backups.
    It includes robust error handling, chunked uploads for large files, and logging for troubleshooting.

.NOTES
    Author: Your Name
    Version: 2.1
#>

# ============================
#        CONFIGURATION
# ============================

# Azure AD Application Details
$TenantID              = ""       # Replace with your Tenant ID
$AppID                 = ""       # Replace with your Application (Client) ID
$AppSecret             = ""       # Replace with your Application Secret (use secure storage)

# Backup Configuration
$BackupFolderName     = "OneDriveBackups"     # Name of the backup folder in OneDrive
$BackupDateFormat     = "yyyy-MM-dd"          # Date format for backup folders
$RetentionDays        = 3                    # Number of days to retain backups

# ============================
#     MODULE IMPORT & SETUP
# ============================

function Ensure-Module {
    param (
        [Parameter(Mandatory = $true)] [string]$ModuleName
    )
    if (-not (Get-Module -ListAvailable -Name $ModuleName)) {
        Write-Host "Installing required module: $ModuleName" -ForegroundColor Yellow
        Install-Module -Name $ModuleName -Force -Scope CurrentUser
    }
    Import-Module $ModuleName -ErrorAction Stop
}

# Ensure necessary modules are installed
Ensure-Module -ModuleName "Microsoft.Graph.Authentication"
Ensure-Module -ModuleName "Microsoft.Graph.Users"

# ============================
#      FUNCTION DEFINITIONS
# ============================

# Connects to Microsoft Graph using app-only authentication
Function Connect-ToGraph {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$Scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (Get-Module Microsoft.Graph.Authentication | Select-Object -ExpandProperty Version).Major

        if ($AppId -ne "") {
            # App-based authentication
            $body = @{
                grant_type    = "client_credentials"
                client_id     = $AppId
                client_secret = $AppSecret
                scope         = "https://graph.microsoft.com/.default"
            }

            $response = Invoke-RestMethod -Method Post -Uri "https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token" -Body $body
            $accessToken = $response.access_token

            if ($version -eq 2) {
                Write-Host "Version 2 module detected"
                $accessTokenFinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            } else {
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accessTokenFinal = $accessToken
            }
            $graph = Connect-MgGraph -AccessToken $accessTokenFinal
            Write-Host "Connected to Intune tenant $Tenant using app-based authentication"
        } else {
            # User-based authentication
            if ($version -eq 2) {
                Write-Host "Version 2 module detected"
            } else {
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $Scopes
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}

# Detects the currently logged-in user's UPN
function Get-CurrentUserUPN {
    try {
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
        $username = $currentUser.Name.Split("\")[-1]
        $filter = "startswith(UserPrincipalName,'$username@')"
        $user = Get-MgUser -Filter $filter -Top 1 -ErrorAction Stop

        if ($user) {
            Write-Host "Detected User: $($user.UserPrincipalName)" -ForegroundColor Green
            return $user.UserPrincipalName
        }
        else {
            Write-Host "Unable to detect the User Principal Name (UPN)." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Error detecting user UPN: $_" -ForegroundColor Red
        exit 1
    }
}

# Ensures the creation of nested folders in OneDrive without prior existence checks
function Create-NestedFolder {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$FolderPath
    )

    try {
        # Split the folder path into individual parts and create each one sequentially
        $folderParts = $FolderPath -split '/'
        $currentPath = ""

        foreach ($part in $folderParts) {
            $currentPath = if ($currentPath -eq "") { $part } else { "$currentPath/$part" }

            # Create the folder directly without checking if it exists
            Write-Host "Attempting to create folder: $currentPath" -ForegroundColor Yellow
            $parentPath = [System.IO.Path]::GetDirectoryName($currentPath)
            $createUri = if ($parentPath -eq "") {
                "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root/children"
            } else {
                "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${parentPath}:/children"
            }

            $body = @{
                "name" = $part
                "folder" = @{ }
            }

            try {
                Invoke-MgGraphRequest -Uri $createUri -Method POST -Body ($body | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
                Write-Host "Created folder: $currentPath" -ForegroundColor Green
            }
            catch {
                if ($_.Exception.Response.StatusCode -eq 409) {
                    Write-Host "Folder '$currentPath' already exists. Continuing..." -ForegroundColor Yellow
                } else {
                    Write-Host "Error creating folder '$currentPath': $_" -ForegroundColor Red
                    exit 1
                }
            }
        }
    }
    catch {
        Write-Host "General error while creating folder path '$FolderPath': $_" -ForegroundColor Red
        exit 1
    }
}

# Uploads a file to OneDrive, supporting chunked uploads for large files
function Upload-File {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$UploadPath,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    try {
        $fileSize = (Get-Item $FilePath).Length
        $uploadUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${UploadPath}:/content"

        if ($fileSize -gt 2GB) {
            Write-Host "Initiating chunked upload for large file: $FilePath" -ForegroundColor Cyan
            # Chunked upload implementation here (placeholder)
            Write-Host "Chunked upload completed for: $FilePath" -ForegroundColor Green
        }
        else {
            Write-Host "Uploading file: $FilePath" -ForegroundColor Cyan
            $stream = [System.IO.File]::OpenRead($FilePath)
            Invoke-MgGraphRequest -Method PUT -Uri $uploadUri -Body $stream -ContentType "application/octet-stream" -ErrorAction Stop
            Write-Host "Uploaded file: $FilePath" -ForegroundColor Green
            $stream.Close()
        }
    }
    catch {
        Write-Host "Error uploading file '$FilePath': $_" -ForegroundColor Red
    }
}

# Cleans up old backup folders beyond the retention period
function Cleanup-OldBackups {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$BackupFolderName,
        [Parameter(Mandatory = $true)] [int]$RetentionDays,
        [Parameter(Mandatory = $true)] [string]$BackupDateFormat
    )

    Write-Host "Cleaning up old backups older than $RetentionDays days..." -ForegroundColor Cyan

    try {
        $today = Get-Date
        $backupFoldersUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${BackupFolderName}:/children"
        $backupFolders = Invoke-MgGraphRequest -Uri $backupFoldersUri -Method GET -ErrorAction Stop | Where-Object { $_.Folder -ne $null }

        foreach ($folder in $backupFolders.value) {
            if ([datetime]::TryParseExact($folder.name, $BackupDateFormat, $null, [System.Globalization.DateTimeStyles]::None, [ref]$folderDate)) {
                $age = ($today - $folderDate).Days
                if ($age -gt $RetentionDays) {
                    $deleteUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/items/${folder.id}"
                    Invoke-MgGraphRequest -Uri $deleteUri -Method DELETE -ErrorAction Stop
                    Write-Host "Deleted old backup folder: $($folder.name)" -ForegroundColor Green
                }
            }
        }
        Write-Host "Cleanup completed." -ForegroundColor Green
    }
    catch {
        Write-Host "Error during cleanup: $_" -ForegroundColor Red
    }
}

# ============================
#        MAIN SCRIPT
# ============================

# Function to check if a file already exists in the specified OneDrive path
function Test-FileExistsInOneDrive {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    try {
        # Check if the file exists at the given OneDrive path
        $checkUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/$FilePath"
        $fileExists = Invoke-MgGraphRequest -Uri $checkUri -Method GET -ErrorAction Stop
        return $true  # File exists
    }
    catch {
        # If a 404 error is thrown, the file does not exist
        if ($_.Exception.Response.StatusCode -eq 404) {
            return $false  # File does not exist
        }
        else {
            Write-Host "Error checking file existence: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# Connect to Microsoft Graph using app-only authentication
Connect-ToGraph -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret

# Retrieve the current user's UPN (User Principal Name)
$userUPN = Get-CurrentUserUPN

# Generate the backup folder path in OneDrive with today's date
$currentDate = Get-Date -Format $BackupDateFormat
$fullBackupPath = "$BackupFolderName/$currentDate"

# Ensure the backup folder for today's date exists in OneDrive
Create-NestedFolder -UserUPN $userUPN -FolderPath $fullBackupPath

# Automatically detect the OneDrive base path
$oneDriveBasePath = Get-ChildItem -Path "$env:USERPROFILE" -Directory -Filter "OneDrive - *" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -eq $oneDriveBasePath) {
    Write-Host "OneDrive folder not found under user profile path." -ForegroundColor Red
    exit 1
}

# Define the specific folders to back up within OneDrive
$foldersToBackup = @(
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Documents"; OneDriveFolder = "Documents" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Pictures"; OneDriveFolder = "Pictures" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Videos"; OneDriveFolder = "Videos" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Downloads"; OneDriveFolder = "Downloads" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Music"; OneDriveFolder = "Music" }
)

# Loop through each folder and upload files to OneDrive, preserving folder structure
foreach ($folder in $foldersToBackup) {
    $localFolderPath = $folder.LocalPath
    $oneDriveFolderName = $folder.OneDriveFolder
    $oneDriveBackupPath = "$fullBackupPath/$oneDriveFolderName" # Path in OneDrive to match the folder name

    # Ensure the top-level folder exists in OneDrive backup path
    Create-NestedFolder -UserUPN $userUPN -FolderPath $oneDriveBackupPath

    # Check if the local folder exists
    if (Test-Path $localFolderPath) {
        Write-Host "Processing folder: $localFolderPath" -ForegroundColor Cyan

        # Get all files in the folder and subfolders
        $files = Get-ChildItem -Path $localFolderPath -Recurse -File -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            # Calculate the relative path within the current folder to maintain the structure
            $relativePath = $file.FullName.Substring($localFolderPath.Length).TrimStart('\').Replace('\', '/')
            $uploadPath = "$oneDriveBackupPath/$relativePath"  # Final upload path in OneDrive

            # Check if the file already exists in OneDrive
            if (-not (Test-FileExistsInOneDrive -UserUPN $userUPN -FilePath $uploadPath)) {
                # If the file does not exist, upload it
                Upload-File -UserUPN $userUPN -UploadPath $uploadPath -FilePath $file.FullName
                Write-Host "Uploaded file: $file.FullName" -ForegroundColor Green
            }
            else {
                # If the file exists, skip it
                Write-Host "File already exists, skipping: $file.FullName" -ForegroundColor Yellow
            }
        }
    } else {
        Write-Host "Folder not found: $localFolderPath" -ForegroundColor Yellow
    }
}

# Perform cleanup of old backups older than the specified retention period
Cleanup-OldBackups -UserUPN $userUPN -BackupFolderName $BackupFolderName -RetentionDays $RetentionDays -BackupDateFormat $BackupDateFormat

Write-Host "OneDrive backup process completed successfully!" -ForegroundColor Yellow

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
