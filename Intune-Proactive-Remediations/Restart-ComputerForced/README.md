<div align="center">

# 🛠️ Forced Restart

**Intune Proactive Remediation package that reboots devices that are waiting for a restart.**

Detection checks common pending-reboot indicators and remediation forces the restart — either after a polite warning delay or immediately, depending on which remediation flavor you assign — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Forced Restart** is an Intune remediation package that clears pending-reboot state across managed devices by forcing the restart Windows is already waiting for.

The detection script evaluates four indicators — Windows Update `RebootRequired`, Component Based Servicing `RebootPending`, `PendingFileRenameOperations`, and a pending computer rename — and writes its verdict to `C:\Intune\RestartStatus.txt`. Both remediations pair with this one detector: **remediate-Restart-ComputerForced.ps1** reads that verdict, warns the user twice with balloon tips, waits 30 minutes plus a final minute, and only then forces the restart; **remediate-Restart-ComputerForcedNow.ps1** skips every warning, delay, and status-file dependency and issues an immediate forced restart for aggressive maintenance windows.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Checks CBS, Windows Update, PendingFileRenameOperations, and computer-rename indicators
* Persists the verdict to `C:\Intune\RestartStatus.txt` for the remediation pair
* Never modifies the system beyond that status file

### 🔹 Verified Remediation (two flavors)
* Delayed flavor: two balloon-tip warnings, configurable wait, then `Restart-Computer -Force`
* Immediate flavor: instant `Restart-Computer -Force`, no warnings and no status-file dependency
* Both emit structured JSON result output for Intune diagnostics before the device cycles

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Restart-ComputerForced\` and `<SystemDrive>\IntuneLogs\Restart-ComputerForcedNow\`

---

# 📂 Project Structure

```text
Restart-ComputerForced
│
├── detect-Restart-ComputerForced.ps1
├── remediate-Restart-ComputerForced.ps1
├── remediate-Restart-ComputerForcedNow.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Restart-ComputerForced.ps1
```

### Purpose
Detects whether Windows is waiting for a restart. Read-only apart from the status file.

### Logic
1. Check Windows Update `RebootRequired` and CBS `RebootPending` registry keys
2. Check `PendingFileRenameOperations` and a pending computer rename (`ComputerName` vs `ActiveComputerName`)
3. Write `'Restart required'` or another verdict to `C:\Intune\RestartStatus.txt`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

Both remediation scripts below pair with the single detector above — assign exactly **one** of them per Intune remediation profile.

**File (delayed flavor)**
```powershell
remediate-Restart-ComputerForced.ps1
```

### Purpose
Warns the user, waits for the configured delay, and then forces a restart when the detector's verdict says one is required.

### Logic
1. Pre-check: read `C:\Intune\RestartStatus.txt`; anything other than `'Restart required'` means nothing to do
2. Fix: show a balloon warning quoting the delay in minutes (`$DelaySeconds = 1800` by default), sleep, show a final one-minute warning, then issue `Restart-Computer -Force`
3. Post-verify: confirm the restart command was issued without error; the device power-cycles immediately afterwards

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (restart command issued or nothing to do) |
| 1    | Failure (verification failed) |
| 2    | Script error |

## ⚡ Immediate Restart Script

**File**
```powershell
remediate-Restart-ComputerForcedNow.ps1
```

### Purpose
Forces an immediate restart with no warnings — the aggressive maintenance-window flavor.

### Logic
1. Pre-check: confirm the `Restart-Computer` cmdlet is available
2. Fix: log a warning line and issue `Restart-Computer -Force` at once; no status file is read and no grace period is given
3. Post-verify: confirm the restart command was issued without error

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (restart command issued) |
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
* Forcing restarts requires elevated (SYSTEM/Administrator) context.

### Logging
* `<SystemDrive>\IntuneLogs\Restart-ComputerForced\`
* `<SystemDrive>\IntuneLogs\Restart-ComputerForcedNow\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Restart-ComputerForced.ps1
```

### Remediation Script (choose ONE per assignment)
```powershell
remediate-Restart-ComputerForced.ps1
```
```powershell
remediate-Restart-ComputerForcedNow.ps1
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
2. Detection exits with code `1` when any pending-reboot indicator is found
3. Intune runs the assigned **Remediation Script**
4. The delayed flavor warns and waits before restarting; the immediate flavor restarts right away

---

# 🛡 Operational Notes
* **A forced restart discards all unsaved user work.** The immediate variant gives no warning at all — assign it only to maintenance scopes, kiosks, or lab devices.
* Balloon tips require an interactive session; on headless SYSTEM-context runs the delayed flavor logs a warning and continues without visible notifications.
* The delayed flavor depends on `C:\Intune\RestartStatus.txt`; if the detection script has never run, the remediation aborts without rebooting.
* Edit `$DelaySeconds` in the delayed remediation to change the warning period.
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
