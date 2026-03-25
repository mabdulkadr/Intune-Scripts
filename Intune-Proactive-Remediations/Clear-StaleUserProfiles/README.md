# 💽 Clear-UserProfileTempFiles – Remove Stale User Profiles with DelProf

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Profile%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Clear-UserProfileTempFiles** looks for user profiles that have not been used within the configured retention window and removes them by downloading and running both `DelProf` and `DelProf2`.

The detection script queries `Win32_UserProfile`, compares `LastUseTime` against a 30-day threshold, and triggers remediation when one or more stale profiles are found. The remediation script repeats the same profile age check, downloads both cleanup utilities from Andrew Taylor's public GitHub repository into `%TEMP%`, runs them with the same day threshold, and deletes the downloaded executables afterward.

This package is a local profile cleanup workflow, not a selective profile management tool.

---

# ✨ Core Features

### 🔹 CIM-Based Stale Profile Detection

Detection uses:

```powershell
Get-CimInstance Win32_UserProfile
```

and treats profiles older than `30` days as cleanup candidates.

---

### 🔹 Dual DelProf Execution

Remediation downloads and runs both:

* `delprof.exe`
* `DelProf2.exe`

with the same age threshold.

---

### 🔹 Temporary Tool Download

The cleanup utilities are downloaded from GitHub into `%TEMP%`, executed locally, then removed.

---

### 🔹 Local Script Logging

The package writes logs under:

```text
<SystemDrive>\IntuneLogs\Clear-UserProfileTempFiles
```

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Clear-UserProfileTempFiles
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Clear-UserProfileTempFiles
│
├── Clear-UserProfileTempFiles--Detect.ps1
├── Clear-UserProfileTempFiles--Remediate.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Clear-UserProfileTempFiles--Detect.ps1
```

### Purpose

Checks whether any local user profiles are older than the configured age threshold.

### Logic

1. Queries `Win32_UserProfile`
2. Filters profiles with `LastUseTime` older than 30 days
3. Returns `1` if one or more matching profiles are found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No stale profiles were found |
| 1    | One or more stale profiles were found |

### Example

```powershell
.\Clear-UserProfileTempFiles--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Clear-UserProfileTempFiles--Remediate.ps1
```

### Purpose

Downloads DelProf utilities and removes profiles older than the configured threshold.

### Actions

The script performs the following steps:

1. Rechecks whether stale profiles exist
2. Downloads `delprof.exe` to `%TEMP%`
3. Runs `delprof.exe /Q /D:30`
4. Downloads `DelProf2.exe` to `%TEMP%`
5. Runs `DelProf2.exe /q /d:30`
6. Deletes both downloaded executables

### Example

```powershell
.\Clear-UserProfileTempFiles--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to enumerate and remove local user profiles
* Internet access to GitHub for downloading the cleanup tools

---

# 🧭 Intune Deployment

This solution is intended for **Intune Proactive Remediations**.

### Detection Script

```powershell
Clear-UserProfileTempFiles--Detect.ps1
```

### Remediation Script

```powershell
Clear-UserProfileTempFiles--Remediate.ps1
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
2. Detection checks for profiles older than 30 days
3. If stale profiles exist, detection exits with code **1**
4. Intune triggers the **Remediation Script**
5. Remediation downloads and runs the DelProf tools

---

# 🛡 Operational Notes

* The script does not exclude specific profiles beyond whatever behavior the DelProf tools enforce internally.
* The remediation script depends on external downloads at runtime.
* Running both `DelProf` and `DelProf2` is redundant in many environments, but that is the current implementation.

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
