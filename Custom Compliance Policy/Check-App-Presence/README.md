
# Check-App-Presence

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Intune](https://img.shields.io/badge/Intune-Compatible-green.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

## Overview
The **Check-App-Presence** script is a **PowerShell-based detection tool** designed to verify whether a specific application is installed on a Windows device. The application(s) to be checked are defined in a **JSON configuration file (`Check-App-Presence.json`)**, making this script flexible for various use cases.

This script is particularly useful for **Microsoft Intune** compliance policies, allowing organizations to ensure that unauthorized software is not installed on managed devices.


---

## Features
✔️ Detects the presence of any specified application on a Windows device.  
✔️ Uses a **JSON configuration file** for easy customization.  
✔️ Returns a **compliance status** based on application presence.  
✔️ Compatible with **Microsoft Intune** for device compliance policies.  
✔️ Supports **multiple applications** by modifying the JSON file.  

---

## Usage

### 1. Modify the JSON Configuration
Edit the `Check-App-Presence.json` file to specify the application(s) you want to detect.

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

> **Note:** Replace `"Google Chrome"` with the name of the application you want to detect.

---

### 2. Run the Script
Execute the PowerShell script to check for the specified application(s).

```powershell
.\Check-App-Presence.ps1
```

---

### 3. Understanding the Output
The script returns a **compliance status** based on application detection:

✅ **Compliance (Exit Code 0):** The application is **not installed** (allowed).  
❌ **Non-Compliance (Exit Code 1):** The application **is installed** (blocked).  

#### Example Output:
If **Google Chrome** is found:
```
Google Chrome is installed.
```
If **Google Chrome** is **not** found:
```
None of the specified applications were found.
```

---

## Customization

1. **To detect a different application,** update `Check-App-Presence.json` with the application's name.
2. **To check for multiple applications,** add multiple rules in the JSON file.
3. **To enforce compliance policies in Intune,** deploy the script as a custom detection rule.

---

## Intune Deployment Guide
This script can be used in **Microsoft Intune** as a **custom compliance policy**:

1. **Go to:** Intune Admin Center → Devices → Compliance policies.
2. **Create a new policy** for Windows 10/11.
3. **Select "Custom Compliance"** and upload both `Check-App-Presence.ps1` and `Check-App-Presence.json`.
4. Define the remediation action (e.g., notify users, restrict access).
5. Assign the policy to the desired **user/device group**.

---

## Example Use Cases
- **Block unauthorized applications** like Google Chrome, Zoom, or third-party browsers.
- **Ensure required software is installed** (modify script logic to enforce required apps).
- **Enforce security policies** by checking for blacklisted applications.

---

## References
- [Intune Custom Device Compliance for Multiple Apps](https://liviubarbat.info/posts/07_intune-custom-device-compliance-for-multiple-apps/)

---

## Notes
- Designed for **Windows 10 and later**.
- Requires **PowerShell 5.1+**.
- Supports **customization for any application** by modifying the JSON file.

---

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer:** This script is provided as-is. Test it in a **staging environment** before deploying to production. The author is not responsible for unintended consequences arising from its use.
