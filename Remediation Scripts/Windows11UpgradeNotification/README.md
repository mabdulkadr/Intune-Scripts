# Windows 11 Upgrade Notification Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0.0-green.svg)

## Introduction

This repository contains two PowerShell scripts designed to notify users about the availability of the Windows 11 upgrade. The scripts are intended to work together:

1. **Detect_Windows11UpgradeNotification.ps1**: A detection script that checks if the device is running Windows 10 and needs the Windows 11 upgrade notification.

2. **Remediate_Windows11UpgradeNotification.ps1**: A remediation script that displays a Windows toast notification informing the user that the Windows 11 upgrade is available. The notification supports both English and Arabic languages based on the system language settings.

---

## Scripts

### 1. Detect_Windows11UpgradeNotification.ps1

#### Synopsis

Detects if the device is running Windows 10 and needs the Windows 11 upgrade notification.

#### Description

This script checks the current operating system version. If the device is running Windows 10, it exits with code `1`, indicating that remediation (displaying the Windows 11 upgrade notification) is needed. If the device is already running Windows 11 or another unsupported OS, it exits with code `0`.

#### Usage

- **Run As**: User
- **Example**:
  ```powershell
  .\Detect_Windows11UpgradeNotification.ps1
  ```
- **Exit Codes**:
  - `0`: No action needed (device is not running Windows 10).
  - `1`: Remediation needed (device is running Windows 10).


### 2. Remediate_Windows11UpgradeNotification.ps1

#### Synopsis

Displays a Windows notification to inform the user that a Windows 11 upgrade is available.

#### Description

This script shows a Windows toast notification indicating that a Windows 11 upgrade is available. The notification supports both English and Arabic languages based on the system language settings. It includes a button that directs the user to the Windows Update settings when clicked.

#### Usage

- **Run As**: User
- **Example**:
  ```powershell
  .\Remediate_Windows11UpgradeNotification.ps1
  ```

## Prerequisites

- **Operating System**: Windows 10 or Windows 11
- **PowerShell**: Version 5.0 or higher
- **Execution Policy**: Scripts should be allowed to run (`RemoteSigned` or `Unrestricted`).
- **Internet Access**: The remediation script downloads images from the internet. Ensure the device has internet connectivity or modify the script to use local images.

---

## Usage

### Step 1: Run the Detection Script

1. **Execute the Detection Script**
   ```powershell
   .\Detect_Windows11UpgradeNotification.ps1
   ```
2. **Interpret the Exit Code**
   - If the script exits with code `1`, proceed to run the remediation script.
   - If the script exits with code `0`, no further action is needed.

### Step 2: Run the Remediation Script (if needed)

1. **Execute the Remediation Script**
   ```powershell
   .\Remediate_Windows11UpgradeNotification.ps1
   ```
2. **What the Script Does**
   - Detects the system language (English or Arabic).
   - Downloads custom images for the notification.
   - Displays a Windows toast notification informing the user about the Windows 11 upgrade availability.
   - The notification includes a button that opens Windows Update settings when clicked.

---

## Notes

- **Permissions**: Ensure the user running the scripts has the necessary permissions, especially when modifying registry entries.
- **Customization**:
  - Modify image URLs to use your organization's logos or images.
  - Adjust notification text to suit your organization's messaging.
  - Localize the notification to additional languages if needed.

---

## Troubleshooting

- **Toast Notification Not Displaying**:
  - Ensure the script is run as the logged-on user, not as an administrator.
  - Verify that the registry entries for toast notifications are correctly set.
  - Check for any typos or syntax errors in the script, especially in the XML structure of the toast notification.

- **Script Execution Policy Errors**:
  - Confirm that the PowerShell execution policy allows the script to run.
  - Use `Get-ExecutionPolicy -List` to view current policies.

- **Image Download Issues**:
  - Verify internet connectivity.
  - Check that the URLs for the images are accessible.
  - Modify the script to use local images if necessary.

---

# License

This project is licensed under the [MIT License](LICENSE).


---

**Disclaimer**: Use these scripts at your own risk. Ensure you understand their impact before running them in a production environment. Always review and test scripts thoroughly.
