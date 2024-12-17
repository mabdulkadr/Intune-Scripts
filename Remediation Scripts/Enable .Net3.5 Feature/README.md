# Enable .NET Framework 3.5 - Detection and Remediation Scripts

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
This repository contains two PowerShell scripts designed to detect and remediate the installation of **.NET Framework 3.5** on Windows 10 and Windows 11 devices. These scripts are intended for deployment via Microsoft Intune using the **Devices | Scripts and remediations** feature.

---

## Scripts Included

1. **Detect_.Net3.5_Feature.ps1**  
   - Detects whether .NET Framework 3.5 is enabled on the target device.

2. **Remediate_.Net3.5_Feature.ps1**  
   - Enables .NET Framework 3.5 if it is not already installed.

---

## Scripts Details

### 1. Detect_.Net3.5_Feature.ps1

#### Purpose
This script checks if the **.NET Framework 3.5** feature is enabled on the device. It outputs a status message and returns an exit code.

#### How to Run
Run locally or deploy via Intune:
```powershell
.\Detect_.Net3.5_Feature.ps1
```

#### Outputs
- **"Installed"**: Indicates .NET Framework 3.5 is enabled.
- **"Not Installed"**: Indicates .NET Framework 3.5 is not enabled.

#### Exit Codes
- **0**: Detection successful (feature is enabled).
- **1**: Detection failed (feature not enabled).

---

### 2. Remediate_.Net3.5_Feature.ps1

#### Purpose
This script enables the **.NET Framework 3.5** feature using the `Add-WindowsCapability` command. It includes error handling and logs the installation process.

#### How to Run
Run locally (requires administrative privileges) or deploy via Intune:
```powershell
.\Remediate_.Net3.5_Feature.ps1
```

#### Outputs
- **Success**: Displays a message confirming .NET Framework 3.5 is enabled.
- **Error**: Outputs an error message if the installation fails.

#### Error Handling
The script includes `try-catch` blocks to handle errors and provide detailed feedback.

---

## Deployment via Intune

1. Go to the **Intune portal**: [https://intune.microsoft.com/](https://intune.microsoft.com/)
2. Navigate to **Devices | Scripts and remediations**.
3. Add the scripts as follows:
   - **Detection Script**: Upload `Detect_.Net3.5_Feature.ps1`.
   - **Remediation Script**: Upload `Remediate_.Net3.5_Feature.ps1`.
4. Assign the scripts to your target device groups.
5. Monitor the deployment status under **Devices | Monitor**.

---

## Notes
- Ensure devices have internet access to download the .NET 3.5 feature from Windows Update.
- If devices use WSUS and cannot access Windows Update, configure the DISM method with a valid source path.

---

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.