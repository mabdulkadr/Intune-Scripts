# PowerShell Script to Backup Local OneDrive Folders to OneDrive via Microsoft Graph API
#
# Description:
# This script connects to Microsoft Graph using application-only authentication and uploads
# specific folders from the user's local OneDrive folder to OneDrive cloud storage.
# It preserves the folder structure and skips files that already exist in OneDrive.
#
# The script performs the following steps:
# - Ensures required PowerShell modules are installed.
# - Connects to Microsoft Graph using app-only authentication.
# - Detects the current user's User Principal Name (UPN).
# - Automatically detects the local OneDrive base path.
# - Defines the folders to back up (Documents, Desktop, Pictures, etc.).
# - Loops through each folder, uploads files to OneDrive while preserving the folder structure,
#   and skips files that already exist.
# - Disconnects from Microsoft Graph upon completion.
#
# Note:
# - Ensure that the Azure AD application has the necessary permissions to access users' OneDrive data.
# - The AppSecret should be securely stored; hardcoding secrets in scripts is not recommended.
#
# Author: [Your Name]
# Date: [Date]

# ============================
#        CONFIGURATION
# ============================

# Azure AD Application Details
$TenantID            = ""      # Replace with your Tenant ID
$AppID               = ""      # Replace with your Application (Client) ID
$AppSecret           = ""      # Replace with your Application Secret (use secure storage)

# Backup Configuration
$BackupFolderName    = "OneDriveBackups"  # The parent folder in OneDrive where backups will be stored



# Check if the current policy is 'Bypass' or 'Unrestricted'
$currentPolicy = Get-ExecutionPolicy -Scope CurrentUser
if ($currentPolicy -eq 'Bypass' -or $currentPolicy -eq 'Unrestricted') {
    Write-Host "Execution policy is already set to $currentPolicy. No changes needed." -ForegroundColor Green
} else {
    Write-Host "Current execution policy is $currentPolicy. Changing to 'Unrestricted'." -ForegroundColor Yellow
    Set-ExecutionPolicy -ExecutionPolicy Unrestricted -Scope CurrentUser -Force
    Write-Host "Execution policy has been set to 'Unrestricted'." -ForegroundColor Green
}


# ============================
#     MODULE IMPORT & SETUP
# ============================

# Function to ensure a required PowerShell module is installed and imported
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

# Ensure necessary modules are installed and imported
Ensure-Module -ModuleName "Microsoft.Graph.Authentication"
Ensure-Module -ModuleName "Microsoft.Graph.Users"
Ensure-Module -ModuleName "Microsoft.Graph.Files"

# ============================
#      FUNCTION DEFINITIONS
# ============================

# Connects to Microsoft Graph using app-only authentication
Function Connect-ToGraph {

    [cmdletbinding()]
    param
    (
        [Parameter(Mandatory = $false)] [string]$Tenant,
        [Parameter(Mandatory = $false)] [string]$AppId,
        [Parameter(Mandatory = $false)] [string]$AppSecret,
        [Parameter(Mandatory = $false)] [string]$scopes
    )

    Process {
        # Import the Microsoft Graph Authentication module
        Import-Module Microsoft.Graph.Authentication

        # Get the major version of the Microsoft Graph Authentication module
        $version = (Get-Module Microsoft.Graph.Authentication | Select-Object -ExpandProperty Version).Major

        if ($AppId -ne "") {
            # If AppId is provided, use app-only authentication

            # Prepare the body for the OAuth 2.0 token request
            $body = @{
                grant_type    = "client_credentials";
                client_id     = $AppId;
                client_secret = $AppSecret;
                scope         = "https://graph.microsoft.com/.default";
            }

            # Request an access token from Azure AD
            $response = Invoke-RestMethod -Method Post -Uri https://login.microsoftonline.com/$Tenant/oauth2/v2.0/token -Body $body

            # Extract the access token from the response
            $accessToken = $response.access_token

            # Output the access token (for debugging purposes)
            $accessToken

            if ($version -eq 2) {
                # For version 2 of the module, convert the access token to a secure string
                Write-Host "Version 2 module detected"
                $accesstokenfinal = ConvertTo-SecureString -String $accessToken -AsPlainText -Force
            }
            else {
                # For version 1 of the module, select the Beta profile
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
                $accesstokenfinal = $accessToken
            }

            # Connect to Microsoft Graph using the access token
            $graph = Connect-MgGraph -AccessToken $accesstokenfinal 

            Write-Host "Connected to Intune tenant $TenantId using app-based authentication (Azure AD authentication not supported)"
        }
        else {
            # If AppId is not provided, use user authentication (interactive)
            if ($version -eq 2) {
                Write-Host "Version 2 module detected"
            }
            else {
                Write-Host "Version 1 Module Detected"
                Select-MgProfile -Name Beta
            }
            $graph = Connect-MgGraph -Scopes $scopes
            Write-Host "Connected to Intune tenant $($graph.TenantId)"
        }
    }
}

# Detects the currently logged-in user's UPN (User Principal Name)
function Get-CurrentUserUPN {
    try {
        # Get the current Windows user's identity
        $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()

        # Extract the username part (after the backslash)
        $username = $currentUser.Name.Split("\")[-1]

        # Prepare a filter to search for the user in Azure AD
        $filter = "startswith(UserPrincipalName,'$username@')"

        # Query Microsoft Graph to find the user matching the filter
        $user = Get-MgUser -Filter $filter -Top 1 -ErrorAction Stop

        if ($user) {
            Write-Host "Detected User: $($user.UserPrincipalName)" -ForegroundColor Green
            return $user.UserPrincipalName
        } else {
            Write-Host "Unable to detect the User Principal Name (UPN)." -ForegroundColor Red
            exit 1
        }
    }
    catch {
        Write-Host "Error detecting user UPN: $_" -ForegroundColor Red
        exit 1
    }
}

# Uploads a file to OneDrive, skipping if the file already exists
function Upload-File {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$UploadPath,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    try {
        # Check if the file already exists in OneDrive
        $existingFile = Test-FileExistsInOneDrive -UserUPN $UserUPN -FilePath $UploadPath

        if ($existingFile -ne $null) {
            Write-Host "File already exists, skipping: $FilePath" -ForegroundColor Yellow
            return  # Skip this file
        }

        # Upload the file if it doesn't exist
        Write-Host "Uploading file: $FilePath" -ForegroundColor Cyan

        # Open the local file as a stream
        $stream = [System.IO.File]::OpenRead($FilePath)

        # Upload the file to OneDrive using Microsoft Graph API
        Invoke-MgGraphRequest -Method PUT -Uri "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${UploadPath}:/content" -Body $stream -ContentType "application/octet-stream" -ErrorAction Stop

        Write-Host "Uploaded file: $FilePath" -ForegroundColor Green

        # Close the file stream
        $stream.Close()
    }
    catch {
        Write-Host "Error uploading file '$FilePath': $_" -ForegroundColor Red
    }
}

# Function to test if a file exists in OneDrive
function Test-FileExistsInOneDrive {
    param (
        [Parameter(Mandatory = $true)] [string]$UserUPN,
        [Parameter(Mandatory = $true)] [string]$FilePath
    )

    try {
        # Construct the URI to check the file in OneDrive
        $checkUri = "https://graph.microsoft.com/v1.0/users/$UserUPN/drive/root:/${FilePath}"

        # Send a GET request to check if the file exists
        $response = Invoke-MgGraphRequest -Uri $checkUri -Method GET -ErrorAction Stop

        return $response  # File exists
    }
    catch {
        # If the status code is 404, the file does not exist
        if ($_.Exception.Response.StatusCode -eq 404) {
            return $null  # File does not exist
        } else {
            Write-Host "Error checking file existence: $_" -ForegroundColor Red
            exit 1
        }
    }
}

# ============================
#        MAIN SCRIPT
# ============================

# Connect to Microsoft Graph using the provided credentials
Connect-ToGraph -Tenant $TenantID -AppId $AppID -AppSecret $AppSecret

# Get the User Principal Name (UPN) of the current user
$userUPN = Get-CurrentUserUPN

Write-Host "Successfully connected to Microsoft Graph" -ForegroundColor Green

# Automatically detect the local OneDrive base path
$oneDriveBasePath = Get-ChildItem -Path "$env:USERPROFILE" -Directory -Filter "OneDrive - *" -ErrorAction SilentlyContinue | Select-Object -First 1

if ($null -eq $oneDriveBasePath) {
    Write-Host "OneDrive folder not found under user profile path." -ForegroundColor Red
    exit 1
}

# Define the specific folders within OneDrive to back up
$foldersToBackup = @(
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Documents"; OneDriveFolder = "Documents" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "المستندات"; OneDriveFolder = "المستندات" }

    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Desktop"; OneDriveFolder = "Desktop" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "سطح المكتب"; OneDriveFolder = "سطح المكتب" }

    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "Pictures";  OneDriveFolder = "Pictures" }
    @{ LocalPath = Join-Path -Path $oneDriveBasePath.FullName -ChildPath "الصور";  OneDriveFolder = "الصور" }


   
    @{ LocalPath = Join-Path -Path "$env:USERPROFILE" -ChildPath "Downloads"; OneDriveFolder = "Downloads" }
    @{ LocalPath = Join-Path -Path "$env:USERPROFILE" -ChildPath "التنزيلات"; OneDriveFolder = "التنزيلات" }

    @{ LocalPath = Join-Path -Path "$env:USERPROFILE" -ChildPath "Videos"; OneDriveFolder = "Videos" }
    @{ LocalPath = Join-Path -Path "$env:USERPROFILE" -ChildPath "ملفات الفيديو"; OneDriveFolder = "ملفات الفيديو" }

    @{ LocalPath = Join-Path -Path "$env:USERPROFILE" -ChildPath "Music"; OneDriveFolder = "Music" }
    @{ LocalPath = Join-Path -Path "$env:USERPROFILE" -ChildPath "الموسيقى"; OneDriveFolder = "الموسيقى" }

)

# Loop through each folder and upload files to OneDrive, preserving folder structure
foreach ($folder in $foldersToBackup) {
    $localFolderPath = $folder.LocalPath
    $oneDriveFolderName = $folder.OneDriveFolder
    $oneDriveBackupPath = "$BackupFolderName/$oneDriveFolderName"  # Path in OneDrive to match the folder name

    if (Test-Path $localFolderPath) {
        Write-Host "Processing folder: $localFolderPath" -ForegroundColor Cyan

        # Get all files in the folder and subfolders
        $files = Get-ChildItem -Path $localFolderPath -Recurse -File -ErrorAction SilentlyContinue

        foreach ($file in $files) {
            # Calculate the relative path within the current folder to maintain the structure
            $relativePath = $file.FullName.Substring($localFolderPath.Length).TrimStart('\').Replace('\', '/')

            # Construct the final upload path in OneDrive
            $uploadPath = "$oneDriveBackupPath/$relativePath"  # Final upload path in OneDrive

            # Upload the file to OneDrive, skipping if it already exists
            Upload-File -UserUPN $userUPN -UploadPath $uploadPath -FilePath $file.FullName
        }
    } else {
        Write-Host "Folder not found: $localFolderPath" -ForegroundColor Yellow
    }
}

Write-Host "OneDrive backup process completed successfully" -ForegroundColor Green

# Disconnect from Microsoft Graph
Disconnect-MgGraph
Write-Host "Disconnected from Microsoft Graph." -ForegroundColor Cyan
Write-Host "OneDrive backup process completed successfully" -ForegroundColor Green
