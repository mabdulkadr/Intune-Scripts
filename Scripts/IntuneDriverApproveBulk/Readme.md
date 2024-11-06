# Automate Windows Driver Update Approvals in Microsoft Intune

This repository contains two PowerShell scripts that automate the approval of pending Windows driver updates in Microsoft Intune using the Microsoft Graph API.

- **`IntuneDriverApproveBulk.ps1`**: Uses user-based authentication (supports MFA).
- **`IntuneDriverApproveBulk-AppAuth.ps1`**: Uses app-based authentication with Azure AD application credentials.

## Overview

Managing driver updates in an enterprise environment can be complex and time-consuming. These scripts simplify the process by automating the approval of Windows driver updates that require review in Microsoft Intune.

## Prerequisites

- **Operating System**: Windows 10 or later.
- **PowerShell Version**: 5.1 or higher (PowerShell Core is also supported).
- **Microsoft .NET Framework**: 4.7.2 or later.
- **Network Access**: Internet connectivity to access the PowerShell Gallery and Microsoft Graph API.
- **Azure AD Account/App Registration**:
  - For user-based authentication: An account with the necessary permissions.
  - For app-based authentication: An Azure AD application with appropriate permissions and admin consent.

## Scripts Description

### IntuneDriverApproveBulk.ps1

- **Authentication Method**: User-based authentication (supports MFA).
- **Purpose**: Connects to Microsoft Graph using a user account, fetches pending driver updates, and approves them for deployment in Intune.
- **Use Case**: Ideal for scenarios where you prefer to authenticate interactively or when MFA is enforced.

### IntuneDriverApproveBulk-AppAuth.ps1

- **Authentication Method**: App-based authentication using Azure AD application credentials.
- **Purpose**: Connects to Microsoft Graph using app credentials (Tenant ID, App ID, App Secret), fetches pending driver updates, and approves them for deployment in Intune.
- **Use Case**: Suitable for automation scenarios where interactive sign-in is not feasible, such as scheduled tasks or CI/CD pipelines.


## Usage

### Using IntuneDriverApproveBulk.ps1

#### Steps:

1. **Run the Script**:

   ```powershell
   .\IntuneDriverApproveBulk.ps1
   ```

2. **Authentication Prompt**:

   - A sign-in window will appear.
   - Log in with your Azure AD account that has the necessary permissions.
   - Complete any MFA prompts if required.

3. **Script Execution**:

   - The script will install any missing modules.
   - It will connect to Microsoft Graph.
   - Fetch driver updates needing review.
   - Approve the drivers for deployment.
   - Disconnect from Microsoft Graph upon completion.

4. **Monitoring Progress**:

   - The console will display messages indicating the progress and any errors encountered.
   - Successful approvals will be highlighted in green.
   - Any failures will be highlighted in red.

### Using IntuneDriverApproveBulk-AppAuth.ps1

#### Steps:

1. **Prepare Azure AD App Registration**:

   - **Register an Application** in Azure AD.
   - **Assign API Permissions**:
     - `DeviceManagementConfiguration.ReadWrite.All` (Application permission).
   - **Grant Admin Consent** for the application permissions.
   - **Generate a Client Secret** and note the value.

2. **Update Script Parameters**:

   - Open `IntuneDriverApproveBulk-AppAuth.ps1` in a text editor.
   - Replace the placeholder values in the `param` block at the top of the script with your actual credentials:

     ```powershell
     param (
         [Parameter(Mandatory = $true)]
         [string]$TenantID = "your-tenant-id",

         [Parameter(Mandatory = $true)]
         [string]$AppID = "your-app-id",

         [Parameter(Mandatory = $true)]
         [string]$AppSecret = "your-app-secret"
     )
     ```

3. **Run the Script**:

   ```powershell
   .\IntuneDriverApproveBulk-AppAuth.ps1
   ```

   Alternatively, pass the parameters directly:

   ```powershell
   .\IntuneDriverApproveBulk-AppAuth.ps1 -TenantID "your-tenant-id" -AppID "your-app-id" -AppSecret "your-app-secret"
   ```

4. **Script Execution**:

   - The script will install any missing modules.
   - It will connect to Microsoft Graph using app-based authentication.
   - Fetch driver updates needing review.
   - Approve the drivers for deployment.
   - Disconnect from Microsoft Graph upon completion.

5. **Monitoring Progress**:

   - Similar to the user-based script, monitor the console output for progress and errors.

## Permissions

- **For User-Based Authentication**:
  - **Azure AD Role**: Intune Administrator or equivalent.
  - **Microsoft Graph Permissions**: `DeviceManagementConfiguration.ReadWrite.All` (Delegated permission).
- **For App-Based Authentication**:
  - **Azure AD App Registration** with:
    - **Application Permission**: `DeviceManagementConfiguration.ReadWrite.All`.
    - **Admin Consent** granted for the permission.

## Authentication Methods

- **User-Based Authentication**:
  - Interactive login.
  - Supports Multi-Factor Authentication (MFA).
  - Requires a user account with necessary permissions.
- **App-Based Authentication**:
  - Non-interactive login using client credentials flow.
  - Suitable for automation and scripts running unattended.
  - Requires Azure AD app registration with appropriate permissions.

## Script Breakdown

Both scripts perform the following actions:

1. **Module Installation and Import**:
   - Ensures that the necessary Microsoft Graph PowerShell modules are installed and imported:
     - `Microsoft.Graph.Authentication`
     - `Microsoft.Graph.Beta.DeviceManagement.Actions`

2. **Authentication**:
   - **IntuneDriverApproveBulk.ps1**: Uses `Connect-MgGraph` with user-based authentication.
   - **IntuneDriverApproveBulk-AppAuth.ps1**: Includes a `Connect-ToGraph` function to authenticate using app credentials.

3. **Fetching and Approving Driver Updates**:
   - Retrieves all Windows driver update profiles.
   - For each profile, fetches driver inventories needing review.
   - Approves each driver by executing the "Approve" action via Microsoft Graph API.
   - Handles pagination to process all drivers.

4. **Disconnecting**:
   - Cleanly disconnects from Microsoft Graph to free up resources.

## Error Handling

- **Module Installation Errors**:
  - If a module fails to install, the script outputs an error message and exits.
- **Driver Approval Errors**:
  - If a driver fails to approve, the script outputs an error message but continues processing other drivers.
- **General Exceptions**:
  - The scripts use try-catch blocks to handle exceptions and provide meaningful error messages.

## Security Considerations

- **App Secrets**:
  - Avoid hardcoding sensitive information like `AppSecret` in scripts.
  - Consider using secure methods to store and retrieve secrets, such as Azure Key Vault or encrypted credential stores.
- **Script Storage**:
  - Store scripts securely and restrict access to authorized personnel.
- **Version Control**:
  - If using version control systems (e.g., Git), ensure that secrets are not committed to the repository.
- **Testing**:
  - Always test scripts in a non-production environment before running them in production.


## License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.

