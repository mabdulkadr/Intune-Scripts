# 🌐 Uninstall-ChromePerUser – Remove Per-User Google Chrome Installations

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Per-User%20App%20Removal-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Uninstall-ChromePerUser** looks for **Google Chrome** registered under the current user's uninstall key and then attempts to remove that per-user installation.

The detection script scans `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall` and treats `Google Chrome` as a blacklisted application. If Chrome is found there, remediation runs. The remediation script then tries to launch the uninstall string silently.

This package appears to be intended for moving users away from per-user Chrome installs and toward a managed enterprise deployment.

---

# ✨ Core Features

### 🔹 HKCU Uninstall Detection

Detection is per-user, not device-wide:

* Reads `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
* Compares `DisplayName` and `DisplayName_Localized`
* Flags `Google Chrome` when found

---

### 🔹 Silent Uninstall Attempt

The remediation script:

* Reads the uninstall string from the same HKCU uninstall entry
* Branches between MSI-style and non-MSI uninstall commands
* Adds silent flags to the launched command

---

### 🔹 Intended Enterprise Cleanup Scenario

The output text makes the purpose clear:

* Detect per-user Chrome
* Remove it
* Prepare the device to rely on an enterprise-managed Chrome installation instead

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Uninstall-ChromePerUser
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Uninstall-ChromePerUser
│
├── README.md
├── Uninstall-ChromePerUser--Detect.ps1
└── Uninstall-ChromePerUser--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Uninstall-ChromePerUser--Detect.ps1
```

### Purpose

Checks whether Google Chrome is registered as a per-user installed application.

### Logic

1. Reads uninstall entries under the current user's registry hive
2. Normalizes the app name from `DisplayName` or `DisplayName_Localized`
3. Counts matches against the blacklist containing `Google Chrome`
4. Returns `1` when a per-user Chrome installation is found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Per-user Chrome not detected |
| 1    | Per-user Chrome detected |

### Example

```powershell
.\Uninstall-ChromePerUser--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Uninstall-ChromePerUser--Remediate.ps1
```

### Purpose

Attempts to remove the per-user Chrome installation by launching its uninstall string silently.

### Actions

1. Reads the current user's uninstall entries
2. Locates `Google Chrome`
3. Extracts the uninstall command
4. Adds silent flags depending on whether the command appears MSI-based or not
5. Launches the uninstall through `cmd.exe /c`

### Example

```powershell
.\Uninstall-ChromePerUser--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The script must run in the user context that owns the per-user Chrome installation

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Uninstall-ChromePerUser--Detect.ps1
```

### Remediation Script

```powershell
Uninstall-ChromePerUser--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | Yes   |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks the current user's uninstall registry entries
3. If Google Chrome is found there, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation launches the uninstall command silently

---

# 🛡 Operational Notes

* The remediation logic is fragile. In the MSI branch, the generated command string appears malformed because the product code parsing does not rebuild the closing brace cleanly.
* The blacklist currently contains only `Google Chrome`, but the script structure implies it was written to support more per-user applications later.
* This package targets the current user's uninstall entries only. It will not detect or remove a machine-wide Chrome install.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.2**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.
