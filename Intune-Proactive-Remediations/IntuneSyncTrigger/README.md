<div align="center">

# ⚙️ Intune IME Sync Trigger

**Intune Proactive Remediation package that verifies and restores Intune Management Extension activity.**

Detection checks the IME service state, log freshness, and recent activity patterns — remediation restarts the service and confirms new activity is written, keeping the Intune sidecar healthy across managed fleets.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Intune IME Sync Trigger** is an Intune remediation package that keeps the Intune Management Extension (sidecar) active on managed devices.

The detection script verifies that the `IntuneManagementExtension` service exists and runs, that its main log was written within the configured 8-hour lookback window, and that recent log lines show operational activity. When any condition fails, Intune runs the paired remediation, which restarts (or starts) the service and waits briefly for a newer log write to confirm activity was triggered.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Checks the `IntuneManagementExtension` service existence and running state
* Validates main log freshness against an 8-hour lookback window
* Scans the latest 300 log lines for practical IME activity keywords
* Never modifies the system during detection

### 🔹 Verified Remediation
* Restarts or starts the IME service with pre-check → fix → post-verify flow
* Confirms a newer IME log write after the action (30-second grace wait)
* Emits structured JSON result output for Intune diagnostics
* Elevation gate before any change; aborts cleanly when prerequisites fail

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\IntuneSyncTrigger\`

---

# 📂 Project Structure

```text
IntuneSyncTrigger
│
├── detect-IntuneSyncTrigger.ps1
├── remediate-IntuneSyncTrigger.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-IntuneSyncTrigger.ps1
```

### Purpose
Verifies recent Intune Management Extension activity. Strictly read-only.

### Logic
1. Confirm the `IntuneManagementExtension` service exists and is running
2. Confirm the main IME log file exists under `ProgramData\Microsoft\IntuneManagementExtension\Logs`
3. Compare the log's last write time against the 8-hour lookback cutoff
4. Scan the last 300 log lines for activity keyword patterns

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-IntuneSyncTrigger.ps1
```

### Purpose
Restores IME activity by restarting or starting the service, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm elevation and that the IME service exists
2. Fix: `Restart-Service` when running, otherwise `Start-Service`
3. Post-verify: wait 30 seconds, then require the service running plus a newer IME log write

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 with the Intune Management Extension agent installed

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\IntuneSyncTrigger\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-IntuneSyncTrigger.ps1
```

### Remediation Script
```powershell
remediate-IntuneSyncTrigger.ps1
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
2. Detection exits with code `1` when IME is missing, idle, or silent
3. Intune runs the **Remediation Script**
4. Remediation restarts the service, verifies new activity, and logs results

---

# 🛡 Operational Notes
* A verified log write proves activity was triggered — it does not prove any specific policy or app finished processing.
* Restarting the IME service interrupts in-flight sidecar operations; schedule assignments accordingly.
* Devices without the IME agent installed always report non-compliant — scope the assignment to eligible devices only.
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

