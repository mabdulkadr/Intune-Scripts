<div align="center">

# 🩺 Get Device Uptime Status

**Intune Proactive Remediation package that reminds users to restart devices with long uptime.**

Detection reads the OS uptime and, once it crosses `7` days, Intune runs the remediation that shows a restart reminder toast with a one-click `shutdown.exe /r /t 0` action — keeping managed fleet memory and patch state fresh.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Device Uptime Status** is an Intune remediation package that nudges users to restart devices before uptime degrades performance or blocks updates.

Devices that stay up for long periods accumulate stale kernel state, pending patches, and driver installs waiting for a reboot. Detection reads `OSUptime` from `Get-ComputerInfo` read-only; when it reaches the configured threshold (`MaxUptimeDays = 7`), Intune runs the paired remediation, which registers a temporary toast AppID under HKCU and displays a restart reminder notification whose action launches `shutdown.exe /r /t 0`. The device itself is never forced to restart.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `OSUptime` from `Get-ComputerInfo`
* Never modifies the system during detection
* Reports non-compliance as soon as the threshold is reached so the reminder cycle starts

### 🔹 User-Facing Notification Remediation
* Registers a temporary AppID (`PowerShell.DeviceUptimeReminder`) under `HKCU:\SOFTWARE\Classes\AppUserModelId`
* Shows a Windows toast with a **Restart now** action (`shutdown.exe /r /t 0`) plus **Dismiss**
* Exits `0` without action when uptime is below threshold — idempotent by design

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Get-DeviceUptimeStatus\`

---

# 📂 Project Structure

```text
Get-DeviceUptimeStatus
│
├── detect-Get-DeviceUptimeStatus.ps1
├── remediate-Get-DeviceUptimeStatus.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Get-DeviceUptimeStatus.ps1
```

### Purpose
Checks whether device uptime has reached the configured threshold. Strictly read-only.

### Logic
1. Read `OSUptime` via `Get-ComputerInfo`
2. Compliant while uptime is below `7` days
3. Non-compliant (by design) once uptime reaches `7` days — this triggers the reminder remediation; unexpected query failures exit with code `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Get-DeviceUptimeStatus.ps1
```

### Purpose
Shows a restart reminder toast when the threshold is reached, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: read current uptime; below threshold exits `0` with no action
2. Fix: register the toast AppID under HKCU, then display the English restart reminder toast
3. Post-verify: confirm the AppID registration exists with the expected display name (display success was enforced by the toast call completing)

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (notification shown, or uptime below threshold) |
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

### Logging
* `<SystemDrive>\IntuneLogs\Get-DeviceUptimeStatus\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Get-DeviceUptimeStatus.ps1
```

### Remediation Script
```powershell
remediate-Get-DeviceUptimeStatus.ps1
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
2. Detection exits with code `1` when uptime reaches the threshold
3. Intune runs the **Remediation Script**
4. Remediation shows the restart reminder, verifies its registration, and logs results

---

# 🛡 Operational Notes
* Scheduled-action package: "non-compliant" here means *the user should be reminded*, not that the device was changed.
* The toast AppID is registered under HKCU. When the pair runs in SYSTEM context on devices with active console sessions, verify toast visibility in your environment; assigning the remediation in user context maximizes visibility.
* The **Restart now** button launches `shutdown.exe /r /t 0` in the user's session — the device is never restarted automatically.
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
