<div align="center">

# ⚙️ Invoke Intune Device Sync

**Intune Proactive Remediation package that keeps IME sync flowing on an hourly cadence.**

Detection looks for a recent IME sync event (Event ID 208) or the recurring sync task as proof of health — remediation fires an immediate sync via the `intunemanagementextension://syncapp` URI and registers an hourly SYSTEM-run task to keep it flowing.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke Intune Device Sync** is an Intune remediation package that restores and maintains Intune Management Extension sync activity.

The detection script queries `Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider/Operational` for Event ID 208 inside a 1-hour lookback window; when no event exists, an enabled `Trigger-IME-Sync-Hourly` scheduled task is accepted as compliant. When both signals are absent, the paired remediation triggers a sync immediately through the Shell.Application COM object and registers the hourly recurring task under the SYSTEM account.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* XPath-filtered query for Event ID 208 within a 1-hour lookback window
* Fallback compliance while the recurring sync task exists and is enabled
* Never modifies the system during detection

### 🔹 Verified Remediation
* Immediate sync via `Shell.Application.Open('intunemanagementextension://syncapp')`
* Registers `Trigger-IME-Sync-Hourly` (SYSTEM, highest run level, repeats hourly)
* Verifies the recurring task exists and is enabled after registration
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Invoke-IntuneDeviceSync\`

---

# 📂 Project Structure

```text
Invoke-IntuneDeviceSync
│
├── detect-Invoke-IntuneDeviceSync.ps1
├── remediate-Invoke-IntuneDeviceSync.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Invoke-IntuneDeviceSync.ps1
```

### Purpose
Detects recent IME sync activity or its fallback schedule. Strictly read-only.

### Logic
1. Query the DeviceManagement-Enterprise-Diagnostics log for Event ID 208 in the last hour
2. Compliant when the event is found
3. Otherwise compliant while `Trigger-IME-Sync-Hourly` exists and is not disabled
4. Non-compliant when neither signal is present

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Invoke-IntuneDeviceSync.ps1
```

### Purpose
Triggers an immediate IME sync and ensures the hourly recurring task, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm Shell.Application COM availability and elevation
2. Fix: open the sync URI via COM, then `Register-ScheduledTask` for the hourly task
3. Post-verify: require the task to exist with a state other than Disabled

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 enrolled in Intune

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs via Intune in SYSTEM or user context per assignment — no Graph permissions required.
* Remediation requires elevation to register the SYSTEM-run task.

### Logging
* `<SystemDrive>\IntuneLogs\Invoke-IntuneDeviceSync\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Invoke-IntuneDeviceSync.ps1
```

### Remediation Script
```powershell
remediate-Invoke-IntuneDeviceSync.ps1
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
2. Detection exits with code `1` when no sync event and no fallback task are found
3. Intune runs the **Remediation Script**
4. Remediation triggers the sync, registers the hourly task, verifies it, and logs results

---

# 🛡 Operational Notes
* The registered hourly task persists independently of Intune — remove the assignment and the task manually if you retire this package.
* An accepted sync request is fire-and-forget: actual policy arrival is asynchronous and re-checked by the detector via Event ID 208.
* The fallback task keeps detection compliant even during quiet hours — disable the task if strict event evidence is required.
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
