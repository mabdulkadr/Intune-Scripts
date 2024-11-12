
# OneDrive Backup Detection and Remediation Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

This repository contains two PowerShell scripts designed for use with Microsoft Intune's Proactive Remediation feature. The scripts help ensure that users' OneDrive for Business folders are properly backed up by detecting the presence of daily backup folders and creating backups when necessary.

- **Detect_OneDriveBackup.ps1**: Detects whether a backup folder with today's date exists in the specified OneDrive backup path.
- **Remediate_OneDriveBackup.ps1**: Creates a backup of the user's OneDrive Desktop folder to their OneDrive for Business account and manages backup retention.

## Scripts

### Detect_OneDriveBackup.ps1

#### Description

This script checks if a folder with the current date (formatted as `yyyy-MM-dd`) exists within a specified OneDrive backup directory. It is used as the detection script in Intune's Proactive Remediation to determine compliance.

#### Features

- Verifies the existence of a daily backup folder in OneDrive.
- Returns an exit code of `0` if the folder exists (compliant) or `1` if it does not (non-compliant).

#### Usage

```powershell
.\Detect_OneDriveBackup.ps1
```

### Remediate_OneDriveBackup.ps1

#### Description

This script performs the backup of the user's OneDrive Desktop folder to their OneDrive for Business account. It includes functionality to:

- Authenticate with Microsoft Graph using app-only authentication.
- Create a backup folder with the current date.
- Upload files from the local OneDrive Desktop folder to the backup location.
- Retain backups for a specified number of days and remove older backups.
- Handle large file uploads using chunked upload sessions.

#### Features

- **Authentication**: Connects to Microsoft Graph using Azure AD app credentials.
- **Backup Creation**: Creates a dated backup folder if it doesn't exist.
- **File Upload**: Uploads files, with support for large files via chunked uploads.
- **Retention Management**: Deletes backups older than the specified retention period.
- **Error Handling**: Includes comprehensive error handling and logging.

#### Usage

```powershell
.\Remediate_OneDriveBackup.ps1
```

## Requirements

- **Operating System**: Windows 10 or later.
- **PowerShell Version**: 5.1 or later.
- **Modules**:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Users`
  - `Microsoft.Graph.Drive`
- **Azure AD Application**:
  - Must have appropriate permissions to access OneDrive for Business via Microsoft Graph.
  - Requires Tenant ID, Application ID, and Application Secret.

## Configuration

### Common Variables

Both scripts require configuration of certain variables to match your environment.

#### Detect_OneDriveBackup.ps1

- `$BackupFolderName`: Name of the backup folder in OneDrive (default: `"OneDriveBackups"`).
- `$BackupDateFormat`: Date format for backup folders (default: `"yyyy-MM-dd"`).
- `$OneDriveFolderName`: Name of the OneDrive folder (e.g., `"OneDrive - Your Organization"`).

#### Remediate_OneDriveBackup.ps1

- **Azure AD Application Details**:
  - `$TenantID`: Your Azure AD Tenant ID.
  - `$AppID`: Your Azure AD Application (Client) ID.
  - `$AppSecret`: Your Azure AD Application Secret. **Ensure this is stored securely.**

- **Backup Configuration**:
  - `$BackupFolderName`: Name of the backup folder in OneDrive (default: `"OneDriveBackups"`).
  - `$BackupDateFormat`: Date format for backup folders (default: `"yyyy-MM-dd"`).
  - `$RetentionDays`: Number of days to retain backups (default: `3`).

- `$OneDriveFolderName`: Name of the OneDrive folder (e.g., `"OneDrive - Your Organization"`).

### Setting Up Azure AD Application

1. **Register an Application** in Azure AD:
   - Navigate to **Azure Portal** > **Azure Active Directory** > **App registrations** > **New registration**.
   - Provide a name and register the application.

2. **Configure API Permissions**:
   - Add **Microsoft Graph** permissions:
     - `Files.ReadWrite.All`
     - `Sites.ReadWrite.All`
   - Grant admin consent for the permissions.

3. **Create a Client Secret**:
   - Navigate to **Certificates & secrets**.
   - Create a new client secret and note it down securely.

4. **Assign Variables**:
   - Update the scripts with your `TenantID`, `AppID`, and `AppSecret`.

## Usage

### Deployment with Intune

1. **Prepare Scripts**:

   - Ensure both scripts are signed if required by your organization's policies.

2. **Add Scripts to Intune**:

   - Navigate to **Microsoft Endpoint Manager Admin Center**.
   - Go to **Devices** > **Scripts and remediations** > **Add** > **Windows 10 and later** > **Add**.

3. **Configure Detection Script**:

   - Upload `Detect_OneDriveBackup.ps1` as the detection script.

4. **Configure Remediation Script**:

   - Upload `Remediate_OneDriveBackup.ps1` as the remediation script.

5. **Assign to Device Groups**:

   - Assign the remediation script to the relevant device or user groups.

6. **Monitor Deployment**:

   - Use Intune's monitoring features to track the compliance and remediation status.


## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.

