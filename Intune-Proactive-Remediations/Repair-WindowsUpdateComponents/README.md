# 🔄 Repair-WindowsUpdateComponents – Update Recency Check and Repair Workflow

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Windows%20Update%20Repair-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Repair-WindowsUpdateComponents** is an Intune remediation package that checks how old the most recent installed Windows update is and, when that age exceeds the configured threshold, runs a broader Windows Update repair routine.

The detection script uses `Get-HotFix` and reads the newest valid `InstalledOn` date. If the last installed update is **40 days** old or older, the device is marked for remediation. The remediation script then runs a multi-step repair sequence that can include the built-in Windows Update troubleshooter, `Repair-WindowsImage -RestoreHealth`, cleanup of paused or deferred update registry values, PowerShell module preparation, `Reset-WUComponents`, and finally a `Get-WindowsUpdate -Install` attempt.

This package is useful when you want a local, device-side signal for stale Windows Update posture and need a more aggressive repair path than simply opening Settings and checking for updates.

---

# ✨ Core Features

### 🔹 Update Age Detection

* Uses `Get-HotFix`
* Selects the newest installed update date
* Flags the device when the most recent update is `40` days old or more

### 🔹 Multi-Step Update Repair

* Runs the built-in Windows Update troubleshooter when available
* Repairs image health with `Repair-WindowsImage -RestoreHealth`
* Removes paused and deferred update policy values from known registry paths

### 🔹 Module-Assisted Recovery

* Attempts to ensure `PSWindowsUpdate` is installed
* Attempts to ensure `FU.WhyAmIBlocked` is installed
* Uses `Reset-WUComponents` and `Get-WindowsUpdate` when those commands are available

### 🔹 Failure Tracking Across Steps

* Tracks warning and failure conditions across the whole workflow
* Returns failure if any important repair step reports problems
* Writes a dedicated DISM log file alongside the main remediation log

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Repair-WindowsUpdateComponents
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Repair-WindowsUpdateComponents
│
├── README.md
├── Repair-WindowsUpdateComponents--Detect.ps1
└── Repair-WindowsUpdateComponents--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Repair-WindowsUpdateComponents--Detect.ps1
```

### Purpose

Checks whether the most recently installed Windows update is older than the package threshold.

### Logic

1. Reads installed hotfix data with `Get-HotFix`
2. Finds the newest valid `InstalledOn` date
3. Calculates the number of days since that update
4. Returns exit code `1` when the age is `40` days or more

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | The latest installed update is newer than the threshold |
| 1    | No valid update history was found, the latest update is too old, or detection failed |

### Key References

* Command: `Get-HotFix`
* Threshold: `40` days

### Example

```powershell
.\Repair-WindowsUpdateComponents--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Repair-WindowsUpdateComponents--Remediate.ps1
```

### Purpose

Runs a layered Windows Update repair routine and then attempts to scan for and install software updates.

### Actions

1. Runs the Windows Update troubleshooter when the troubleshooting cmdlets and pack are available
2. Runs `Repair-WindowsImage -Online -RestoreHealth`
3. Removes common pause and deferral values from Windows Update-related registry paths
4. Installs or verifies the `PSWindowsUpdate` and `FU.WhyAmIBlocked` modules
5. Imports `PSWindowsUpdate` when available
6. Runs `Reset-WUComponents` when available
7. Runs `Get-WindowsUpdate -Install -AcceptAll -UpdateType Software -IgnoreReboot`
8. Returns failure if any critical step reported warnings or failed

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | All tracked remediation steps completed without reported failures |
| 1    | One or more remediation steps failed, were unavailable in a required path, or reported warnings that the script treats as failure |

### Key References

* Command: `Repair-WindowsImage -Online -RestoreHealth`
* Module: `PSWindowsUpdate`
* Module: `FU.WhyAmIBlocked`
* Registry: `HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UpdatePolicy\Settings`
* Registry: `HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\Update`

### Example

```powershell
.\Repair-WindowsUpdateComponents--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* The scripts are intended to run as `System`
* Permission to repair the Windows image and modify update-related registry values
* Internet or repository access may be required if PowerShell modules need to be installed

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Repair-WindowsUpdateComponents`
* A dedicated DISM log is written to `WindowsUpdateTroublshooting-DISM.txt`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Repair-WindowsUpdateComponents--Detect.ps1
```

### Remediation Script

```powershell
Repair-WindowsUpdateComponents--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection checks the age of the latest installed Windows update
3. If the update age is `40` days or more, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation performs Windows Update troubleshooting, servicing repair, policy cleanup, component reset, and update scan/install steps

---

# 🛡 Operational Notes

* Detection is based on hotfix installation history, not on Windows Update service health alone
* The remediation workflow is intentionally broad and may depend on optional modules or commands being available
* The script treats some warning paths as failure so Intune surfaces that the repair was not clean
* Module installation can fail in restricted environments, which will affect the final result
* Test carefully on pilot devices before wide deployment, especially on systems governed by WSUS, update rings, or locked-down PowerShell repository settings

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

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-%E2%98%95-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.

