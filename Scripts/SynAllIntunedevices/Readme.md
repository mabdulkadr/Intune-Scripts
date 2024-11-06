# Intune Device Sync Scripts
![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-7.0%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

Automates the synchronization of all enrolled devices in Microsoft Intune via Microsoft Graph API.

## Description

This repository contains two PowerShell scripts that automate the synchronization of devices managed by Microsoft Intune:

1. **SynsAllIntuneDevices.ps1**: Uses **user-based authentication** (supports Multi-Factor Authentication) to connect to Microsoft Graph API and synchronize all managed devices.

2. **SynsAllIntuneDevices-AppAuth.ps1**: Uses **app-based authentication** with Azure AD application credentials to connect to Microsoft Graph API and synchronize all managed devices.

Both scripts install the necessary Microsoft Graph modules if they are not already installed, handle paginated results to ensure all devices are processed, and ensure proper disconnection from Microsoft Graph upon completion.

## Features

- Installs Microsoft Graph modules if not already present.
- Supports both user-based (SynsAllIntuneDevices.ps1) and app-based (SynsAllIntuneDevices - AppAuth.ps1) authentication.
- Retrieves all managed devices in Intune, handling pagination.
- Sends a sync command to each device to initiate synchronization.
- Disconnects from Microsoft Graph after execution.

## Prerequisites

- **PowerShell 5.1** or higher.
- Permissions to install PowerShell modules (if not already installed).
- An **Azure AD application** with the necessary permissions (for app-based authentication).
- **Microsoft Graph PowerShell SDK**.

## Permissions

Ensure that the Azure AD application or user account has the following Microsoft Graph API permissions:

- `CloudPC.ReadWrite.All`
- `Domain.Read.All`
- `Directory.Read.All`
- `DeviceManagementConfiguration.ReadWrite.All`
- `DeviceManagementManagedDevices.ReadWrite.All`
- `DeviceManagementManagedDevices.PrivilegedOperations.All`

## Usage

### SynsAllIntuneDevices.ps1 (User-Based Authentication)

This script uses **user-based authentication**, which supports Multi-Factor Authentication (MFA). It prompts you to sign in with your user account.

#### Running the Script

1. **Open PowerShell**

2. **Execute the Script**

   ```powershell
   .\SynsAllIntuneDevices.ps1
   ```

   The script will prompt you to sign in with your Microsoft account.

### SynsAllIntuneDevices - AppAuth.ps1 (App-Based Authentication)

This script uses **app-based authentication** with Azure AD application credentials.

#### Parameters

- **`TenantID`**: Your Azure AD tenant ID.
- **`AppID`**: The application (client) ID of your Azure AD app registration.
- **`AppSecret`**: The client secret of your Azure AD app registration.
- **`Scopes`**: (Optional) The scopes required for user-based authentication.

#### Running the Script

1. **Open PowerShell**

2. **Execute the Script**

   ```powershell
   .\SynsAllIntuneDevices-AppAuth.ps1 -TenantID "your-tenant-id" -AppID "your-app-id" -AppSecret "your-app-secret"
   ```

   Replace the placeholders with your actual tenant ID, app ID, and app secret.

### Examples

#### User-Based Authentication

```powershell
.\SynsAllIntuneDevices.ps1
```

#### App-Based Authentication

```powershell
.\SynsAllIntuneDevices-AppAuth.ps1 -TenantID "12345678-90ab-cdef-1234-567890abcdef" -AppID "abcdef12-3456-7890-abcd-ef1234567890" -AppSecret "your-app-secret"
```

## Notes

- **Security Warning**: Avoid hardcoding sensitive information like `AppSecret` in scripts. Consider using secure methods to store and retrieve secrets, such as Azure Key Vault or encrypted credential files.
- **Module Installation**: The scripts check for the Microsoft Graph Authentication module and install it if it's not found.
- **Authentication**: Choose the script that matches your authentication preference.
- **Pagination Handling**: The scripts handle paginated results to ensure all devices are retrieved and processed.

## Contributing

Contributions are welcome! Please open an issue or submit a pull request for any improvements or bug fixes.

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Disclaimer

These scripts are provided "as is" without warranty of any kind. Use them at your own risk. Always test scripts in a controlled environment before deploying them in a production environment.

