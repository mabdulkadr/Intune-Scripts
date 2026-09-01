<div align="center">

# 🛡️ Repair Intune Sync Service

**Intune Proactive Remediation package that recovers stalled Intune sync services and re-triggers management tasks.**

Detection validates the DmWapPushService and IntuneManagementExtension services plus recent IME log activity, and remediation restarts the services and fires every EnterpriseMgmt sync task — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair Intune Sync Service** is an Intune remediation package that restores devices where Intune activity has stalled even though the management stack is still installed.

The detection script inspects `DmWapPushService` and `IntuneManagementExtension` through CIM, validates their start mode and running state, and reviews timestamps from IME log files under `C:\ProgramData\Microsoft\IntuneManagementExtension\Logs` against a staleness threshold (default 24 hours). When checks fail, Intune runs the paired remediation that starts/restarts both services, discovers every scheduled task under `\Microsoft\Windows\EnterpriseMgmt\`, triggers them, and verifies at least one sync task fired.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries service state and start mode via CIM (`Win32_Service`)
* Parses CMTrace-style timestamps from up to nine known IME log files
* Flags stale IME activity beyond `ThresholdHours = 24`; never modifies the system

### 🔹 Verified Remediation
* Ensures `DmWapPushService` is running, then restarts or starts `IntuneManagementExtension`
* Triggers each discovered EnterpriseMgmt task via `Start-ScheduledTask` with an automatic `schtasks.exe /Run` fallback
* Verifies at least one sync task triggered; emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-IntuneSyncService\`
* Preserved legacy dual-write: remediation entries are mirrored into the IME health log when present

---

# 📂 Project Structure

```text
Repair-IntuneSyncService
│
├── detect-Repair-IntuneSyncService.ps1
├── remediate-Repair-IntuneSyncService.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-IntuneSyncService.ps1
```

### Purpose
Checks core Intune sync services and recent IME log activity. Strictly read-only.

### Logic
1. Query `DmWapPushService`: missing or not running is an issue; non-Auto start mode is strict-mode-only
2. Query `IntuneManagementExtension` (when `RequireIME` is enabled): same rules
3. Collect the newest timestamp across candidate IME logs; stale beyond 24 hours is an issue

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-IntuneSyncService.ps1
```

### Purpose
Recovers stalled Intune sync by repairing services and triggering EnterpriseMgmt sync tasks, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `DmWapPushService` exists (missing service fails the remediation)
2. Fix: ensure the transport service runs, restart/start the IME (waits 8 seconds), trigger every discovered EnterpriseMgmt task
3. Post-verify: pass only when at least one sync task was triggered successfully

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (no sync task could be triggered) |
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
* `<SystemDrive>\IntuneLogs\Repair-IntuneSyncService\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-IntuneSyncService.ps1
```

### Remediation Script
```powershell
remediate-Repair-IntuneSyncService.ps1
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
2. Detection exits with code `1` when a service check or IME freshness check fails
3. Intune runs the **Remediation Script**
4. Remediation recovers services, triggers sync tasks, verifies, and logs results

---

# 🛡 Operational Notes
* Former command-line parameters are now fixed configuration values (`ThresholdHours = 24`, `RequireIME = True`, `StrictStartMode = False`, `TailLines = 300`) — edit the CONFIGURATION block to change them.
* Non-Auto start modes only cause non-compliance when `StrictStartMode` is enabled.
* Devices without the IME installed report `IME not installed` and will not benefit from the remediation.
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
