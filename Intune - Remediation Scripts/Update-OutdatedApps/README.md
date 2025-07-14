
# Intune Application Update Management

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Version](https://img.shields.io/badge/version-2.0-green.svg)

## Overview
This Project contains **Microsoft Intune Detection and Remediation Scripts** that check for outdated applications and update them **excluding Java-related applications (JDK, JRE, OpenJDK)** using **Winget**.

The solution ensures that only **non-Java applications** are updated while maintaining compliance with **Intune's compliance policies and remediation actions**.

## Scripts Included

### 1. **Detect-OutdatedApps.ps1**
   - Detects outdated applications using **Winget**.
   - Excludes Java-related applications (`JDK`, `JRE`, `OpenJDK`).
   - Returns `"Compliant"` if all apps are up-to-date.
   - Returns `"Non-Compliant"` if updates (excluding Java) are found.

### 2. **Remediate-OutdatedApps.ps1**
   - Upgrades outdated applications **except Java applications**.
   - Runs updates in **silent mode** to avoid user prompts.
   - Logs update actions to **`C:\Intune\update_log.txt`**.
   - Ensures compliance by keeping applications up to date.

---

## **Scripts Details**

### 1. **Detect-OutdatedApps.ps1**

#### **Purpose**
This script detects outdated applications using **Winget**, while excluding **Java-based applications**.

#### **How to Run**
The script can be deployed in **Microsoft Intune Compliance Policies** under **Devices > Compliance Policies > Scripts**.

#### **Outputs**
- `"Compliant"` → No updates required.
- `"Non-Compliant"` → Updates (excluding Java) are available.

---

### 2. **Remediate-OutdatedApps.ps1**

#### **Purpose**
This script updates all outdated applications while **excluding Java applications** and ensures silent installations.

#### **How to Run**
The script can be deployed as a **Proactive Remediation in Intune** under **Devices > Remediations**.

#### **Outputs**
- **Log File:** Updates are logged in **`C:\Intune\update_log.txt`** for troubleshooting.
- **Silent Mode:** Runs Winget updates without requiring user interaction.

---

## **Logging and Troubleshooting**
- The remediation script **logs all update activities** in `C:\Intune\update_log.txt`.
- If an update fails, review the log file for details.
- Ensure `winget` is installed and functioning by running:

    ```powershell
    winget --version
    ```

- Run the detection script manually to check compliance:

    ```powershell
    .\Detect-OutdatedApps.ps1
    ```

---

## **Notes**
- **System Requirements:** Windows 10/11 with **Winget** installed.
- **Excludes:** Java-related applications to prevent conflicts with development environments.
- **Runs as SYSTEM** in Intune for **seamless silent updates**.

---

## License 
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

**Disclaimer**:  
These scripts are provided as-is. Test them in a staging environment before deploying in production. The author is not responsible for any unintended outcomes resulting from their use.
