# Check-App-Version

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Intune](https://img.shields.io/badge/Intune-Compatible-green.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
This project contains a PowerShell script and a JSON configuration file designed to be used as a **custom compliance policy** in Microsoft Intune. The script checks whether a specified application (e.g., Google Chrome) is installed on a device and validates its version against a required minimum version.

### Features
- Detects if a specified application is installed.
- Validates the application's version (if configured).
- Checks both system-wide installations (`HKLM`) and user-based installations (`HKCU`).
- Outputs JSON results formatted for Intune compliance policy checks.
- Reports non-compliance if the application is outdated or missing.

## Scripts Included
1. **Check-App-Version.ps1**
   - Detects application installation and version.
   - Returns JSON output for Intune compliance checks.
2. **Check-App-Version.json**
   - Defines the compliance rule (application name, version, and remediation message).

---

## Script Details

### 1. Check-App-Version.ps1

#### Purpose
This script queries the Windows Registry to check whether a specified application is installed and, if applicable, verifies its version against a predefined requirement.

#### How to Run
```powershell
.\Check-App-Version.ps1
```

#### Configuration
- **Modify only the application name** in the script and the application name and version in the JSON file.
- Ensure the application name matches exactly as shown in `Add or Remove Programs` (appwiz.cpl).
- Update the following:
  - `Check-App-Version.ps1`: Change `$applicationName = @("YourAppName")`
  - `Check-App-Version.json`: Change `"SettingName": "YourAppName"` and `"Operand": "YourAppVersion"`


#### Outputs
- A JSON object containing key-value pairs:
  - **Key**: Application name.
  - **Value**: Installed version or `false` if not installed.

---

### 2. Check-App-Version.json

#### Purpose
Defines the compliance policy rule for Intune, specifying:
- The application name to check.
- The required minimum version.
- The compliance operator (e.g., `GreaterEquals`).
- A remediation message if non-compliant.

#### Example JSON Rule
```json
{
    "Rules":  [
        {
            "SettingName":  "Google Chrome",
            "Operator":  "GreaterEquals",
            "DataType":  "Version",
            "Operand":  "133.0.6943.54",
            "MoreInfoUrl":  "https://www.momar.tech",
            "RemediationStrings":  [
                {
                    "Language":  "en_US",
                    "Title":  "Google Chrome is outdated or not installed. Value discovered was {ActualValue}.",
                    "Description":  "Make sure to install or update Google Chrome"
                }
            ]
        }
    ]
}
```

---

## Deployment in Intune
1. **Upload `Check-App-Version.ps1`** as a detection script in Intune.
2. **Upload `Check-App-Version.json`** as the compliance policy rule.
3. Assign the compliance policy to target devices.
4. Monitor compliance reports in the Intune admin center.

---

## References
- [Intune Custom Device Compliance for Multiple Apps](https://liviubarbat.info/posts/07_intune-custom-device-compliance-for-multiple-apps/)

## Notes
- This script is designed for **Microsoft Intune Custom Compliance Policies**.
- Only modify the **application name** in both the script and JSON file.
- Test in a staging environment before deployment in production.

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**: These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.

