<div align="center">

# ⚙️ Invoke Device Management Sync

**Intune Proactive Remediation package that keeps the EnterpriseMgmt device management sync fresh.**

Detection measures the age of the newest valid `PushLaunch` scheduled-task run under `Microsoft\Windows\EnterpriseMgmt` — remediation sends a start request to each matching task so the device management sync fires again on stale devices.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke Device Management Sync** is an Intune remediation package that triggers the Microsoft Enterprise Management sync when it has gone quiet.

The detection script enumerates every scheduled task named `PushLaunch` under `\Microsoft\Windows\EnterpriseMgmt\`, safely handles multiple matches, selects the newest valid `LastRunTime`, and flags the device when that run is older than 2 days (or missing/never ran). The paired remediation then issues a start request per matching task, waits briefly, and verifies at least one start was accepted.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Enumerates all `PushLaunch` tasks under the EnterpriseMgmt task path
* Filters out sentinel dates for tasks that never ran
* Selects the newest valid `LastRunTime` and compares against a 2-day threshold
* Never modifies the system during detection

### 🔹 Verified Remediation
* Sends a `Start-ScheduledTask` request per matching task with failure tracking
* Captures before/after task metadata (`LastRunTime`, `LastTaskResult`, `NextRunTime`)
* Verifies at least one start request was accepted; emits structured JSON output
* Pre-check aborts cleanly before any change when no matching task exists

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Invoke-DeviceManagementSync\`

---

# 📂 Project Structure

```text
Invoke-DeviceManagementSync
│
├── detect-Invoke-DeviceManagementSync.ps1
├── remediate-Invoke-DeviceManagementSync.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Invoke-DeviceManagementSync.ps1
```

### Purpose
Checks whether the device management sync task ran within the allowed interval. Strictly read-only.

### Logic
1. Find every `PushLaunch` task under `\Microsoft\Windows\EnterpriseMgmt\`
2. Read each task's info; skip null or never-run sentinel timestamps
3. Pick the newest valid `LastRunTime`
4. Non-compliant when no tasks exist, none ran validly, or the newest run exceeds 2 days

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Invoke-DeviceManagementSync.ps1
```

### Purpose
Starts each matching PushLaunch task to trigger a device management sync attempt, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm at least one matching PushLaunch task exists
2. Fix: `Start-ScheduledTask` per task with per-target failure tracking
3. Post-verify: wait 5 seconds, read updated metadata, require at least one accepted start

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 enrolled in Intune (EnterpriseMgmt tasks present)

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs via Intune in SYSTEM or user context per assignment — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Invoke-DeviceManagementSync\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Invoke-DeviceManagementSync.ps1
```

### Remediation Script
```powershell
remediate-Invoke-DeviceManagementSync.ps1
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
2. Detection exits with code `1` when PushLaunch is stale, missing, or never ran
3. Intune runs the **Remediation Script**
4. Remediation starts the tasks, verifies acceptance, and logs results

---

# 🛡 Operational Notes
* An accepted start request is the guaranteed outcome — the sync itself runs asynchronously inside the EnterpriseMgmt task; policy arrival is confirmed by the next detection cycle.
* Devices with no EnterpriseMgmt tasks report non-compliant but cannot be fixed by remediation — scope assignments to enrolled devices only.
* Multiple PushLaunch tasks are common (one per enrollment); all of them receive a start request.
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
