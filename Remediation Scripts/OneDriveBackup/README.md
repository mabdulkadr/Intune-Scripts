
# OneDrive Backup via Microsoft Graph API

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Overview

This project provides a solution to back up local OneDrive folders to OneDrive cloud storage using Microsoft Graph API. It includes:

- **Detection Script**: Determines if a backup is necessary by checking for files that need to be uploaded.
- **Remediation Script**: Performs the backup operation, uploading files to OneDrive while preserving folder structure and skipping existing files.

The scripts are designed to be deployed as **Proactive Remediation** scripts in Microsoft Intune.


## Features

- **Automated Backup**: Uploads specified local folders to OneDrive cloud storage.
- **Folder Structure Preservation**: Maintains the original folder hierarchy in the backup.
- **Skip Existing Files**: Avoids re-uploading files that already exist in OneDrive.
- **Localization Support**: Handles folder names in different languages.
- **Logging**: Records actions and outputs to a log file for auditing and troubleshooting.
- **Integration with Intune**: Designed to be deployed as proactive remediation scripts in Microsoft Intune.

## Prerequisites

- **Microsoft Intune**: Access to deploy proactive remediation scripts.
- **Azure Active Directory Application**: An app registration with the necessary permissions.
- **Permissions**:
  - **Microsoft Graph API Permissions**:
    - `Files.ReadWrite.All` (Application permission)
    - `User.Read.All` (Application permission)
- **PowerShell Modules**:
  - `Microsoft.Graph.Authentication`
  - `Microsoft.Graph.Users`
  - `Microsoft.Graph.Files`
- **Windows Devices**: Target devices running Windows with PowerShell available.

## Configuration

### Azure AD Application Details

You will need to replace placeholders in the scripts with your actual Azure AD application details:

- **Tenant ID**: `"Your-Tenant-ID"`
- **Application (Client) ID**: `"Your-App-ID"`
- **Application Secret**: `"<YourAppSecret>"` (Store securely; do not hardcode in scripts)

### Backup Configuration

- **Backup Folder Name**: `"OneDriveBackups"` (The parent folder in OneDrive where backups will be stored)

## Deployment Instructions

### 1. Prepare Azure AD Application

1. **Register a New App in Azure AD**:
   - Navigate to **Azure Active Directory** > **App registrations** > **New registration**.
   - Provide a name (e.g., "OneDrive Backup App") and register the application.

2. **Configure API Permissions**:
   - Go to the **API permissions** section of your app.
   - Add the following **Application permissions** under **Microsoft Graph**:
     - `Files.ReadWrite.All`
     - `User.Read.All`
   - Click **Grant admin consent**.

3. **Create Client Secret**:
   - In the **Certificates & secrets** section, create a new client secret.
   - **Store the secret securely**; you'll need it for the scripts.

4. **Gather Application Details**:
   - **Tenant ID**: Found in **Azure Active Directory** > **Properties**.
   - **Application ID**: Found on the **Overview** page of your app registration.
   - **Client Secret**: The value you saved earlier.

### 2. Configure the Scripts

- **Replace Placeholders**:
  - Open both the detection and remediation scripts.
  - Replace `"Your-Tenant-ID"` with your actual Tenant ID.
  - Replace `"Your-App-ID"` with your actual Application ID.
  - **Securely reference** the `AppSecret`; avoid hardcoding it in the script.

- **Securely Store App Secret**:
  - Use a secure method to provide the App Secret to the script, such as:
    - Storing it in an environment variable.
    - Using Azure Key Vault.
    - Prompting for it securely within the script.

### 3. Deploy via Intune

1. **Access Intune Portal**:
   - Navigate to **Microsoft Endpoint Manager admin center**.

2. **Create Proactive Remediation**:
   - Go to **Devices** > **Script and remediations**.
   - Click **+ Create**.

3. **Configure Script Package**:
   - **Name**: Provide a meaningful name (e.g., "OneDrive Backup").
   - **Description**: Optionally, add a description.

4. **Upload Scripts**:
   - **Detection Script**: Upload the detection script (`DetectionScript.ps1`).
   - **Remediation Script**: Upload the remediation script (`RemediationScript.ps1`).

5. **Script Settings**:
   - **Run this script using the logged-on credentials**: **No** (runs as System).
   - **Enforce script signature check**: **No** (unless your scripts are signed).
   - **Run script in 64-bit PowerShell**: **Yes**.

6. **Scope Tags**:
   - Assign any scope tags if necessary.

7. **Assignments**:
   - Assign the script to the desired device groups.

8. **Schedule**:
   - Set the frequency for the script to run (e.g., daily, weekly).

9. **Review and Create**:
   - Review your settings and click **Create**.

## Script Details

### Detection Script

- **Purpose**: Checks if there are files in the specified local folders that need to be backed up.
- **Operation**:
  - Scans user profiles for specified folders.
  - If files are found, outputs a detection result indicating remediation is needed.
- **Output**: JSON string `{ "DetectionResult": true }` or `{ "DetectionResult": false }`.

### Remediation Script

- **Purpose**: Performs the backup operation, uploading files to OneDrive.
- **Operation**:
  - Connects to Microsoft Graph using app-only authentication.
  - Iterates through user profiles and specified folders.
  - Uploads files to OneDrive, preserving folder structure.
  - Skips files that already exist in OneDrive.
  - Logs actions to `C:\Intune\BackupLog.txt`.
- **Logging**: Records detailed logs for auditing and troubleshooting.

## Notes

- **Localization Support**: The scripts handle folder names in different languages, such as Arabic.
- **User Profiles**: Scripts iterate through all user profiles except system and default accounts.
- **Error Handling**: Scripts include error handling to log and continue past errors without stopping the entire process.


## Testing

Before deploying to production, perform thorough testing:

1. **Test in a Controlled Environment**:
   - Use virtual machines or test devices that mimic your production environment.
2. **Monitor Logs**:
   - Check `C:\Intune\BackupLog.txt` for any errors or issues.
3. **Verify OneDrive Backup**:
   - Confirm that files are correctly uploaded to the specified OneDrive accounts.
4. **Adjust as Necessary**:
   - Modify scripts based on testing outcomes to address any issues.

## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.




































