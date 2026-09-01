<div align="center">

# ⏰ Windows Uptime Restart Notification

**Intune Proactive Remediation package that repairs Windows component store and system file integrity.**

Detection checks pending-reboot indicators and runs a read-only DISM health check; remediation follows up with DISM RestoreHealth and SFC /scannow, then reports whether a reboot is required — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Windows Uptime Restart Notification** is an Intune remediation package that detects and repairs component store corruption and system file integrity violations on managed devices.

The detection script combines two signals: common pending-reboot indicators (CBS `RebootPending`, Windows Update `RebootRequired`, `PendingFileRenameOperations`) and the fast, read-only `dism.exe /Online /Cleanup-Image /CheckHealth` status query. When either signal flags an issue, Intune runs the paired remediation, which executes `DISM /RestoreHealth` followed by `sfc.exe /scannow`, classifies the SFC outcome from its console output, and exits with code `3010` when a reboot is required to finalize the repairs.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Checks CBS, Windows Update, and PendingFileRenameOperations reboot indicators
* Runs DISM `CheckHealth` (status query only — never repairs during detection)
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* DISM RestoreHealth followed by SFC /scannow with per-target failure tracking and pre-check → fix → post-verify flow
* SFC output classified into NoIssues / Repaired / Unrepaired; unrepaired files fail the run
* Preserved exit `3010` when a reboot is required, plus structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\WindowsUptimeRestartNotification\`

---

# 📂 Project Structure

```text
WindowsUptimeRestartNotification
│
├── detect-WindowsUptimeRestartNotification.ps1
├── remediate-WindowsUptimeRestartNotification.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-WindowsUptimeRestartNotification.ps1
```

### Purpose
Detects whether Windows system health repair is required. Strictly read-only.

### Logic
1. Check the three common pending-reboot registry indicators
2. Run `dism.exe /Online /Cleanup-Image /CheckHealth` and inspect its exit code and output for corruption markers
3. Compliant only when no reboot is pending and DISM reports no issues

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-WindowsUptimeRestartNotification.ps1
```

### Purpose
Repairs component store and system file integrity issues, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `dism.exe`/`sfc.exe` are available and record the pre-repair reboot state
2. Fix: run `DISM /Online /Cleanup-Image /RestoreHealth`; on success run `sfc.exe /scannow` and classify the output (a failed RestoreHealth skips the SFC scan)
3. Post-verify: require a successful DISM run and no "unable to fix" SFC result; exit `3010` when a reboot is pending before or after the repair

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 3010 | Success, but a reboot is required to finalize repairs |
| 1    | Failure (repair could not be completed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.
* DISM and SFC operations require elevated (SYSTEM/Administrator) context.

### Logging
* `<SystemDrive>\IntuneLogs\WindowsUptimeRestartNotification\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-WindowsUptimeRestartNotification.ps1
```

### Remediation Script
```powershell
remediate-WindowsUptimeRestartNotification.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` when a reboot is pending or DISM flags corruption
3. Intune runs the **Remediation Script**
4. Remediation repairs the component store and system files, then exits `3010` so a reboot can be scheduled

---

# 🛡 Operational Notes
* DISM RestoreHealth can run for an extended period (often 10–30 minutes on unhealthy devices); allow generous timeouts in the Intune assignment.
* Exit `3010` is intentional legacy behavior — configure follow-up automation to reboot devices that report it.
* When SFC reports unrepaired files, inspect `%WinDir%\Logs\CBS\CBS.log`; the script deliberately fails the run rather than masking the issue.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.

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

