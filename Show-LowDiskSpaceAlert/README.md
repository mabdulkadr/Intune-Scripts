<div align="center">

# 🔔 Show Low Disk Space Alert

**Intune Proactive Remediation package that warns users when their C: drive runs low on free space.**

Detection measures the free-space percentage on `C:` against a configurable threshold and remediation builds a disk-usage HTML report and delivers a Windows toast notification so the user can act — built for enterprise fleet hygiene.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Show Low Disk Space Alert** is an Intune remediation package that turns low disk space into an actionable user notification.

The detection script reads `Win32_LogicalDisk` for drive `C:` and compares free space to `$Percent_Alert` (default 20%). At or below the threshold, Intune runs the paired remediation: it analyzes what consumes the disk (user profile, OneDrive, temp folders, downloads, largest files), renders two pie charts plus an HTML report in `%TEMP%\DiskSize_Report.html`, registers a custom notification identity, and dispatches a WinRT toast with buttons that open the report. The alert intentionally fires on schedule whenever space is low so users are nudged to clean up.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `Win32_LogicalDisk` for `C:` via WMI/CIM — never modifies the system during detection
* Compares free-space percentage against `$Percent_Alert`
* Unreadable or invalid disk data exits `2` instead of triggering remediation

### 🔹 Rich User Remediation
* Full disk analysis: user profile, OneDrive, temp folders, downloads, top files and folders
* Two pie charts (`Disk_Size_Pie.png`, `Local_Size_Pie.png`) embedded in an HTML report
* Original WinRT toast mechanism preserved, including hero image, attribution, and action buttons

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Show-LowDiskSpaceAlert\`

---

# 📂 Project Structure

```text
Show-LowDiskSpaceAlert
│
├── detect-Show-LowDiskSpaceAlert.ps1
├── remediate-Show-LowDiskSpaceAlert.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Show-LowDiskSpaceAlert.ps1
```

### Purpose
Checks whether C: free space is at or below the configured alert threshold. Strictly read-only.

### Logic
1. Query `Win32_LogicalDisk` for device `C:` via CIM
2. Compute the free-space percentage and log it with GB figures
3. Non-compliant when free space is at or below `$Percent_Alert`; unreadable disk data raises exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Show-LowDiskSpaceAlert.ps1
```

### Purpose
Analyzes disk usage, writes an HTML user report with pie charts, and dispatches the low-disk-space toast, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `C:` returns valid WMI disk data
2. Fix: run the original analysis (profile/OneDrive/temp scans, charts, `%TEMP%\DiskSize_Report.html`), register the notification app in HKCU, then show the toast via `ToastNotificationManager`
3. Post-verify: confirm the toast dispatch call completed — user acknowledgment cannot be verified programmatically

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logged-On User
* Required — the toast, HKCU notification registration, and user-profile scans only work in an interactive session; deploy with "Run this script using logged-on credentials: Yes".

### Logging
* `<SystemDrive>\IntuneLogs\Show-LowDiskSpaceAlert\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Show-LowDiskSpaceAlert.ps1
```

### Remediation Script
```powershell
remediate-Show-LowDiskSpaceAlert.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | Yes (required - toast needs user context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` when free space is at or below the threshold
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation analyzes usage, writes the report, shows the toast, and logs results

---

# 🛡 Operational Notes
* The full-disk scan can take several minutes on large drives; keep the remediation schedule reasonable.
* Toast text, threshold, logo, and report toggles are all configuration variables at the top of the remediation script.
* Verification is honest by design: success means the toast was dispatched, not that the user acted on it.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.
* The legacy local-content filter excludes paths matching `*OneDrive - METSYS*`; adjust it if your tenant uses a different OneDrive display name.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)
## 📜 License
This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠ Disclaimer

This skill and every script it generates are provided as-is with no warranty of any kind. Test generated tools in a staging environment before deploying to production. The authors assume no liability for any damage or data loss resulting from their use.

---
<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>
