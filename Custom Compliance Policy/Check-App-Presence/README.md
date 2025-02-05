
# Check-App-Presence

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Intune](https://img.shields.io/badge/Intune-Compatible-green.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
The **Check-App-Presence** project contains a PowerShell script and a JSON configuration file designed for **custom compliance policies in Microsoft Intune**. The script checks whether a specified application (e.g., **Google Chrome**) is installed on a device and reports its compliance status. This allows organizations to enforce policies that block unauthorized software.

### Features
- Detects if a **specific application** is installed.
- Uses a **JSON configuration file** for flexibility.
- Supports **multiple applications** (if configured).
- Outputs JSON results for **Intune compliance policy checks**.
- Reports **non-compliance** if the application is found.

## Scripts Included
1. **Check-App-Presence.ps1**
   - Detects whether a specified application is installed.
   - Returns JSON output for Intune compliance checks.
2. **Check-App-Presence.json**
   - Defines the compliance rule (application name and remediation message).

---

## Script Details

### 1. Check-App-Presence.ps1

#### Purpose
This script checks the Windows Registry to determine whether a **specific application** is installed. It is primarily used for compliance checks in **Microsoft Intune**.

#### How to Run
```powershell
.\Check-App-Presence.ps1
```

#### Configuration
- Modify only the **application name** in both the script and the JSON file.
- Ensure that the application name **exactly matches** how it appears in `Add or Remove Programs` (`appwiz.cpl`).
- Update the following:
  - `Check-App-Presence.ps1`: Change `$AppNames = @("YourAppName")`
  - `Check-App-Presence.json`: Change `"SettingName": "YourAppName"`

#### Outputs
- **Exit Code 0** → Compliance: The application **is not installed**.
- **Exit Code 1** → Non-compliance: The application **is installed**.

#### Example Output
If **Google Chrome** is found:
```
Google Chrome is installed.
```
If **Google Chrome** is **not found**:
```
None of the specified applications were found.
```

---

### 2. Check-App-Presence.json

#### Purpose
Defines the **Intune compliance policy rule**, specifying:
- The **application name** to check.
- The **compliance operator** (`IsEquals` for presence checks).
- A **remediation message** if non-compliant.

#### Example JSON Rule (for Google Chrome)
```json
{
    "Rules":  [
        {
            "SettingName":  "Google Chrome",
            "Operator":  "IsEquals",
            "DataType":  "Boolean",
            "Operand":  false,
            "MoreInfoUrl":  "https://www.google.com/chrome/",
            "RemediationStrings":  [
                {
                    "Language":  "en_US",
                    "Title":  "Google Chrome is installed.",
                    "Description":  "Please uninstall this software."
                }
            ]
        }
    ]
}
```
> **Note:** Replace `"Google Chrome"` with any application name you need to check.

---

## Deployment in Intune
To enforce compliance policies in **Microsoft Intune**, follow these steps:

1. **Upload `Check-App-Presence.ps1`** as a detection script in Intune.
2. **Upload `Check-App-Presence.json`** as the compliance policy rule.
3. Assign the compliance policy to the **targeted device groups**.
4. Monitor compliance results in **Microsoft Endpoint Manager (Intune)**.

---

## Example Use Cases
- **Ensure critical applications are Installed** (e.g., Antivirus software, Security tools).
- **Block unauthorized software** (e.g., **Google Chrome, Zoom, TeamViewer**).
- **Ensure unwanted applications are removed** (e.g., legacy apps no longer allowed).
- **Improve security** by restricting non-compliant software.

---

## References
- [Microsoft Intune Custom Compliance Policies](https://learn.microsoft.com/en-us/mem/intune/protect/device-compliance-get-started)

---

## Notes
- This script is designed for **Microsoft Intune Custom Compliance Policies**.
- Modify only the **application name** in the script and JSON file.
- Test in a **staging environment** before deploying in production.

---

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer:** These scripts are provided as-is. Test them in a staging environment before use in production. The author is not responsible for any unintended outcomes resulting from their use.
