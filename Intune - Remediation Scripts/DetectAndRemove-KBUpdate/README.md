# KB Update Detection and Removal Script

![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Intune](https://img.shields.io/badge/Intune-Supported-green.svg)
![Windows](https://img.shields.io/badge/Windows-10%2F11-blue.svg)

## Overview
This PowerShell script is designed to **detect and remove a specific Windows KB update** from devices. It is particularly useful for managing **compatibility issues** caused by certain updates. The script can be deployed via **Microsoft Intune Remediations** to ensure compliance across all managed devices.

## Features
- **Detection:** Checks if a specific KB update is installed.
- **Remediation:** Uninstalls the update if detected.
- **Silent Execution:** Runs without user intervention.
- **Intune Deployment:** Designed for deployment via Microsoft Intune.

## Scripts Included
1. **Detect-KBUpdate.ps1** - Checks if the KB update is installed.
2. **Remediate-KBUpdate.ps1** - Uninstalls the KB update if found.

## Script Details

### **1. Detect-KBUpdate.ps1**
#### Purpose
Detects whether a specified KB update is installed on a device.

#### How to Run
```powershell
.\Detect-KBUpdate.ps1
```
#### Output
- **Exit Code 0:** KB update **not found** (compliant).
- **Exit Code 1:** KB update **found** (non-compliant, triggers remediation).

### **2. Remediate-KBUpdate.ps1**
#### Purpose
Uninstalls the specified KB update if it is detected.

#### How to Run
```powershell
.\Remediate-KBUpdate.ps1
```
#### Output
- **Uninstalls the KB update silently.**
- **A restart may be required** after removal.

## Important Note
- **You must change the KB number** in both `Detect-KBUpdate.ps1` and `Remediate-KBUpdate.ps1` before deploying to ensure it targets the correct update.

## How to Deploy via Intune
1. **Go to Intune Admin Center** ([https://intune.microsoft.com/](https://intune.microsoft.com/)).
2. Navigate to **Devices > Scripts and Remediations**.
3. Click **Add Remediation**.
4. Enter a **Name** (e.g., `Uninstall KB Update`).
5. Upload the **Detection script** (`Detect-KBUpdate.ps1`).
6. Upload the **Remediation script** (`Remediate-KBUpdate.ps1`).
7. Configure the script settings:
   - Run script as **SYSTEM**.
   - Enforce script signature check: **No**.
   - Run script in 64-bit PowerShell: **Yes**.
8. Assign the remediation policy to **target devices**.
9. Click **Save & Deploy**.

## Notes
- The script **only removes the specified KB update** and does not affect other system updates.
- A **restart may be required** for the changes to take effect.
- Logs can be reviewed in **Intune reports** to verify successful execution.

## License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---
**Disclaimer:** These scripts are provided as-is. Test them in a staging environment before deploying them in production. The author is not responsible for any unintended outcomes resulting from their use.

