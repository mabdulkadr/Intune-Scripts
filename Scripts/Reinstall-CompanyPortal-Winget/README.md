# Reinstall Company Portal

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
This PowerShell script ensures the Microsoft Company Portal is correctly installed by:
1. Checking if `winget` is available on the system.
2. Uninstalling the Microsoft Company Portal if it is already installed.
3. Reinstalling the Microsoft Company Portal from the Microsoft Store.

This script provides automated, user-friendly functionality to maintain the proper installation of the Company Portal application.

### Features
- Detects and resolves the path to `winget`.
- Automatically uninstalls and reinstalls the Company Portal.
- Uses the correct `winget` commands for reliability.
- Provides clear output and error handling for a smooth user experience.

## Prerequisites
- **Windows 10 or later**.
- **PowerShell 5.1 or later**.
- **Administrative Privileges** to run the script.
- **`winget` Installed** (included with App Installer). If `winget` is not installed, the script provides guidance to install it.

## How to Use
1. Open PowerShell as an Administrator.
2. Run the script:
    ```powershell
    ./Reinstall-CompanyPortal.ps1
    ```

### Script Flow
1. **Administrative Privilege Check**: Ensures the script is run as an administrator.
2. **Resolve `winget` Path**: Dynamically locates the `winget` executable.
3. **Uninstall Company Portal**: Removes the existing Company Portal application using:
    ```powershell
    winget uninstall --name "Company Portal"
    ```
4. **Install Company Portal**: Installs the latest version of Company Portal using:
    ```powershell
    winget install "Company Portal" --source msstore --accept-package-agreements --accept-source-agreements
    ```

## Outputs
- **Success Messages**: Displays confirmation of uninstallation and reinstallation.
- **Error Messages**: Provides detailed error information if an issue occurs during the process.

## Notes
- Ensure `winget` is installed and functional on your system.
- Test the script in a non-production environment before deploying.

## License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: This script is provided as-is. Use at your own risk. Test thoroughly before using in production environments.
