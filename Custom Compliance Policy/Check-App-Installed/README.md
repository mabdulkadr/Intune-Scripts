# Check If Application is Installed - Intune Custom Compliance Policy

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Intune](https://img.shields.io/badge/Intune-Custom%20Compliance-green.svg)

## Overview
This Project contains a PowerShell script designed for use with Microsoft Intune custom compliance policies. The script checks whether specific applications (both Win32 and Microsoft Store apps) are installed on enrolled devices and returns the result as a JSON object. Intune can then use this JSON output to determine compliance status.

## Features
- Checks for applications installed via traditional Win32 installers (registry-based detection).
- Detects Microsoft Store apps (Appx/MSIX packages).
- Outputs compliance data in JSON format for Intune.
- Supports custom-defined application names.

## How It Works
The script:
1. Defines one or a list of applications to check.
2. Retrieves installed programs from Windows registry.
3. Queries installed Microsoft Store applications (Appx packages).
4. Generates a JSON output indicating the installation status of each application.

## Files Included
### 1. **Check-App-Installed.ps1** (PowerShell script)
#### Purpose
Checks if specific applications are installed and returns JSON output for Intune compliance.

#### How to Run
```powershell
.\Check-App-Installed.ps1
```

#### Output Format (Example JSON):
```json
{"Installed":true}
```

---

### 2. **Check-App-Installed.json** (Intune JSON configuration)
#### Purpose
Defines the compliance policy rule that checks whether an application is installed.

#### Example JSON Rule:
```json
{
    "Rules": [
        {
            "SettingName": "Installed",
            "Operator": "IsEquals",
            "DataType": "Boolean",
            "Operand": false,
            "MoreInfoUrl": "https://www.momar.tech",
            "RemediationStrings": [
                {
                    "Language": "en_US",
                    "Title": "App is not installed on the system.",
                    "Description": "App on the device"
                }
            ]
        }
    ]
}
```
*Note: Do not change anything in the JSON file*

---

## How to Use
### Modify the PowerShell Script
Edit the `$applicationName` array in `Check-App-Installed.ps1` to include the applications you want to check.
```powershell
[array]$applicationName = @("Google Chrome")
```

## Notes
- Ensure the script runs in the **system context** for registry access.
- The JSON configuration should match the application names used in the PowerShell script.
- For Microsoft Store apps, use the package family name if needed.

## License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

## Disclaimer
These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

