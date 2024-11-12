<#
.SYNOPSIS
    Backs up the local OneDrive for Business folder to the user's OneDrive online account.

.DESCRIPTION
    This script connects to OneDrive for Business using app-only authentication, creates a backup folder,
    uploads the latest files from the local OneDrive folder, retains backups for the last three days,
    and removes any older backups. It also supports chunked uploads for large files.

.NOTES
    Author: Your Name
    Date: YYYY-MM-DD
    Version: 1.1
#>

# ============================
#        VARIABLES
# ============================

# Azure AD Application Details
$TenantID = ""  # Replace with your Tenant ID
$AppID = ""     # Replace with your Application (Client) ID
$AppSecret = ""  # Replace with your Application Secret (use secure storage)

# Backup Configuration
$BackupFolderName = "OneDriveBackups"               # Name of the backup folder in OneDrive
$BackupDateFormat = "yyyy-MM-dd"                    # Date format for backup folders
$RetentionDays = 3                                  # Number of days to retain backups

# OneDrive Path Configuration
$OneDriveFolderName = "OneDrive - Your Organization"  # Replace with your OneDrive folder name

# ============================
#      FUNCTION DEFINITIONS
# ============================

# Connects to Microsoft Graph with app-only authentication
function Connect-ToGraph {
     [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$TenantID,
        [Parameter(Mandatory = $false)] [string]$AppID,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$scopes
    )

    Process {
        Import-Module Microsoft.Graph.Authentication
        $version = (get-module microsoft.graph.authentication | Select-Object -expandproperty Version).major

        if ($AppId -ne "") {
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $AppSecret;
                scope         = "https://graph.microsoft.com/.default";
            }
     
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body
            $accessToken = $response.access_token
     
            $accessToken
            if ($version -eq 2) {
                write-host "Version 2 module detected"
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                write-host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }
            $graph = Connect-MgGraph  -AccessToken $accesstokenfinal 
            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            if ($version -eq 2) {
                write-host "Version 2 module detected"
            }
            else {
                write-host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -scopes $scopes
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
            Write-Host "👤 Detected User: $($user.UserPrincipalName)" -ForegroundColor Green
            return $user.UserPrincipalName
        }
        else {
            Write-Host "❌ Unable to detect the User Principal Name (UPN)." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "❌ Error detecting user UPN: $_" -ForegroundColor Red
        exit 1
    }
}

# Retrieves the Drive ID for the user's OneDrive
function Get-DriveId {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN
    )

    try {
        $drive = Get-MgUserDrive -UserId $UserUPN -ErrorAction Stop | Select-Object -First 1
        if ($drive.DriveType -eq "business") {
            Write-Host "✅ Drive ID retrieved: $($drive.Id)" -ForegroundColor Green
            return $drive.Id
        }
        else {
            Write-Host "❌ No OneDrive for Business found for user $UserUPN." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "❌ Error retrieving Drive ID: $_" -ForegroundColor Red
        exit 1
    }
}

# Ensures the backup folder exists, and creates it if it does not
function Ensure-BackupFolder {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$BackupFolderName
    )

    try {
        $uri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${BackupFolderName}:"
        $folder = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction SilentlyContinue

        if (-Not $folder) {
            Write-Host "🛠 Backup folder not found. Creating..." -ForegroundColor Yellow
            $newFolderUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root/children"
            $body = @{
                "name" = $BackupFolderName
                "folder" = @{}
            }
            Invoke-MgGraphRequest -Uri $newFolderUri -Method POST -Body ($body | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
            Write-Host "✅ Backup folder created: $BackupFolderName" -ForegroundColor Green
        }
        else {
            Write-Host "✅ Backup folder exists: $BackupFolderName" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Error ensuring backup folder: $_" -ForegroundColor Red
        exit 1
    }
}

# Uploads files to OneDrive, supporting chunked uploads for large files
function Upload-LargeFile {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$UploadPath,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    Write-Host "🔄 Initiating upload session for large file: $FilePath" -ForegroundColor Cyan

    # Create an upload session
    $uploadSessionUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${UploadPath}:/createUploadSession"
    $uploadSession = Invoke-MgGraphRequest -Uri $uploadSessionUri -Method POST -Body (@{} | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
    $uploadUrl = $uploadSession.uploadUrl

    $chunkSize = 5MB  # Adjustable chunk size
    $fileStream = [System.IO.File]::OpenRead($FilePath)
    $fileSize = $fileStream.Length
    $uploadedBytes = 0
    $maxRetries = 3  # Number of retries for failed uploads

    try {
        while ($uploadedBytes -lt $fileSize) {
            $remainingBytes = $fileSize - $uploadedBytes
            $currentChunkSize = if ($remainingBytes -gt $chunkSize) { $chunkSize } else { $remainingBytes }
            $buffer = New-Object byte[]($currentChunkSize)
            $fileStream.Read($buffer, 0, $currentChunkSize) | Out-Null

            # Define the byte range for the current chunk
            $rangeStart = $uploadedBytes
            $rangeEnd = $uploadedBytes + $currentChunkSize - 1
            $headers = @{
                "Content-Range" = "bytes $rangeStart-$rangeEnd/$fileSize"
            }

            # Retry logic
            $attempt = 0
            $success = $false
            while (-not $success -and $attempt -lt $maxRetries) {
                try {
                    Invoke-WebRequest -Uri $uploadUrl -Method PUT -Body $buffer -Headers $headers -ContentType "application/octet-stream" -TimeoutSec 120 -ErrorAction Stop
                    Write-Host "✅ Uploaded chunk: $rangeStart-$rangeEnd" -ForegroundColor Green
                    $success = $true
                }
                catch {
                    $attempt++
                    Write-Host ("⚠️ Attempt {0} failed for chunk {1}-{2}: {3}" -f $attempt, $rangeStart, $rangeEnd, $_) -ForegroundColor Yellow
                    Start-Sleep -Seconds 5  # Wait before retrying
                    if ($attempt -eq $maxRetries) {
                        throw "❌ Max retries reached for chunk $rangeStart-$rangeEnd. Upload failed."
                    }
                }
            }

            # Update the uploaded bytes counter
            $uploadedBytes += $currentChunkSize
        }

        Write-Host "✅ Large file upload completed successfully." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error during large file upload: ${_}" -ForegroundColor Red
    }
    finally {
        $fileStream.Close()
    }
}




# Uploads files from the local path to the backup folder on OneDrive
function Upload-Backup {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$BackupFolderName,
        [Parameter(Mandatory = $true)] [string]$LocalPath,
        [Parameter(Mandatory = $true)] [string]$BackupDateFormat
    )

    $currentDate = Get-Date -Format $BackupDateFormat
    $currentBackupPath = "$BackupFolderName/$currentDate"
    Write-Host "🗂 Creating today's backup folder: $currentDate" -ForegroundColor Cyan

    try {
        $uri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${currentBackupPath}:"
        $existingFolder = Invoke-MgGraphRequest -Uri $uri -Method GET -ErrorAction SilentlyContinue

        if (-Not $existingFolder) {
            Write-Host "📁 Backup folder for today not found. Creating..." -ForegroundColor Yellow
            $newFolderUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${BackupFolderName}:/children"
            $body = @{
                "name" = $currentDate
                "folder" = @{}
            }
            Invoke-MgGraphRequest -Uri $newFolderUri -Method POST -Body ($body | ConvertTo-Json) -ContentType "application/json" -ErrorAction Stop
            Write-Host "✅ Today's backup folder created: $currentDate" -ForegroundColor Green
        }
        else {
            Write-Host "✅ Today's backup folder already exists: $currentDate" -ForegroundColor Green
        }
    }
    catch {
        Write-Host "❌ Error creating today's backup folder: $_" -ForegroundColor Red
        exit 1
    }

    Write-Host "⬆️ Starting file upload..." -ForegroundColor Cyan

    try {
        $files = Get-ChildItem -Path $LocalPath -Recurse -File

        foreach ($file in $files) {
            $relativePath = $file.FullName.Substring($LocalPath.Length).TrimStart('\').Replace('\', '/')
            $uploadPath = "$currentBackupPath/$relativePath"

            # Check if the file is larger than 2 GB and use chunked upload if needed
            if ($file.Length -gt 2GB) {
                Upload-LargeFile -UserUPN $UserUPN -UploadPath $uploadPath -FilePath $file.FullName
            }
            else {
                Write-Host "📤 Uploading: $relativePath" -ForegroundColor DarkCyan
                try {
                    $stream = [System.IO.File]::OpenRead($file.FullName)
                    Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${uploadPath}:/content" -Body $stream -ContentType "application/octet-stream" -ErrorAction Stop
                    Write-Host "✅ Uploaded: $relativePath" -ForegroundColor Green
                }
                catch {
                    Write-Host "⚠️ Failed to upload $relativePath : $_" -ForegroundColor Yellow
                }
                finally {
                    if ($stream) { $stream.Close() }
                }
            }
        }

        Write-Host "✅ File upload completed." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error during file upload: $_" -ForegroundColor Red
        exit 1
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

    Write-Host "🧹 Cleaning up backups older than $RetentionDays days..." -ForegroundColor Cyan

    try {
        $today = Get-Date
        $backupFolders = Get-MgUserDriveItem -UserId $UserUPN -Path $BackupFolderName -ExpandProperty Children -ErrorAction Stop | Where-Object { $_.Folder -ne $null }

        foreach ($folder in $backupFolders) {
            if ([datetime]::TryParseExact($folder.Name, $BackupDateFormat, $null, [System.Globalization.DateTimeStyles]::None, [ref]$folderDate)) {
                $age = ($today - $folderDate).Days
                if ($age -gt $RetentionDays) {
                    Remove-MgUserDriveItem -UserId $UserUPN -ItemId $folder.Id -ErrorAction Stop
                    Write-Host "🗑 Removed old backup folder: $($folder.Name)" -ForegroundColor Green
                }
            }
        }

        Write-Host "✅ Cleanup completed." -ForegroundColor Green
    }
    catch {
        Write-Host "❌ Error during cleanup: $_" -ForegroundColor Red
        exit 1
    }
}

# ============================
#        MAIN SCRIPT
# ============================

# Connect to Microsoft Graph
Connect-ToGraph -TenantID $TenantID -AppID $AppID -AppSecret $AppSecret

# Get Current User UPN
$userUPN = Get-CurrentUserUPN

# Get Drive ID (used for other functions if needed)
$driveId = Get-DriveId -UserUPN $userUPN

# Ensure Backup Folder Exists
Ensure-BackupFolder -UserUPN $userUPN -BackupFolderName $BackupFolderName

# Get OneDrive for Business Path
Write-Host "📁 Locating OneDrive for Business path..." -ForegroundColor Cyan
$oneDrivePath = Join-Path -Path "$env:USERPROFILE" -ChildPath $OneDriveFolderName

if (-Not (Test-Path $oneDrivePath)) {
    Write-Host "❌ OneDrive for Business path not found at: $oneDrivePath" -ForegroundColor Red
    exit 1
}

Write-Host "📂 OneDrive for Business Path: $oneDrivePath" -ForegroundColor Green

# Upload Backup
Upload-Backup -UserUPN $userUPN -BackupFolderName $BackupFolderName -LocalPath (Join-Path -Path $oneDrivePath -ChildPath "Desktop") -BackupDateFormat $BackupDateFormat

# Cleanup Old Backups
Cleanup-OldBackups -UserUPN $userUPN -BackupFolderName $BackupFolderName -RetentionDays $RetentionDays -BackupDateFormat $BackupDateFormat

Write-Host "🎉 === OneDrive Desktop Backup Process Completed Successfully === 🎉" -ForegroundColor Yellow

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "🔌 Disconnected from Microsoft Graph." -ForegroundColor Cyan
