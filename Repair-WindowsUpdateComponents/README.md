<div align="center">

# 🛡️ Repair Windows Update Components

**Intune Proactive Remediation package that repairs a stalled Windows Update stack end to end.**

Detection verifies the last installed update is newer than 40 days, and remediation runs the troubleshooter, DISM RestoreHealth, policy-value cleanup, component reset, and a pending-update install — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair Windows Update Components** is an Intune remediation package that recovers devices whose Windows Update stack has stalled.

The detection script compares the newest `InstalledOn` date from `Get-HotFix` against a 40-day threshold; devices with no dated updates or an expired one are marked non-compliant. The paired remediation then runs the full recovery workflow: the built-in Windows Update troubleshooter (when available), `Repair-WindowsImage -Online -RestoreHealth` with a dedicated DISM log, removal of paused/deferred update policy values, preparation of the `PSWindowsUpdate` and `FU.WhyAmIBlocked` modules, `Reset-WUComponents`, and finally a `Get-WindowsUpdate -Install` scan.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads installed hotfix history via `Get-HotFix`
* Flags devices whose last update is older than `UpdateThresholdDays = 40`
* Never modifies the system during detection

### 🔹 Verified Remediation
* Runs the built-in troubleshooter and DISM image repair with per-step failure tracking
* Cleans paused/deferred Windows Update policy registry values from two known paths
* Prepares modules, resets update components, and installs pending software updates
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-WindowsUpdateComponents\`

---

# 📂 Project Structure

```text
Repair-WindowsUpdateComponents
│
├── detect-Repair-WindowsUpdateComponents.ps1
├── remediate-Repair-WindowsUpdateComponents.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-WindowsUpdateComponents.ps1
```

### Purpose
Verifies that the last installed Windows update is recent enough. Strictly read-only.

### Logic
1. Query hotfixes via `Get-HotFix` and find the newest valid `InstalledOn` date
2. Non-compliant when no dated updates exist or the newest exceeds the threshold
3. Compliant when the last update age is below `UpdateThresholdDays = 40`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-WindowsUpdateComponents.ps1
```

### Purpose
Repairs and resets Windows Update components using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the `Repair-WindowsImage` command exists
2. Fix: run the troubleshooter (if available), `Repair-WindowsImage -RestoreHealth`, registry policy cleanup, module preparation/import, `Reset-WUComponents`, and `Get-WindowsUpdate -Install`
3. Post-verify: pass only when every executed step completed without warnings or failures

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (one or more steps reported warnings or failures) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.
* Internet access to the PowerShell Gallery is required when `PSWindowsUpdate` or `FU.WhyAmIBlocked` are not already installed.

### Logging
* `<SystemDrive>\IntuneLogs\Repair-WindowsUpdateComponents\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-WindowsUpdateComponents.ps1
```

### Remediation Script
```powershell
remediate-Repair-WindowsUpdateComponents.ps1
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
2. Detection exits with code `1` when the last update exceeds the threshold
3. Intune runs the **Remediation Script**
4. Remediation executes the full repair workflow, verifies it, and logs results

---

# 🛡 Operational Notes
* Long-running steps (troubleshooter, RestoreHealth, update install) keep the original no-timeout wait — expect extended runtimes on slow links.
* `Reset-WUComponents` destroys Windows Update history as part of the reset; treat this as a destructive maintenance action.
* A missing troubleshooter or `Reset-WUComponents` command logs a warning without failing the run; a missing `Get-WindowsUpdate` command does fail the run (preserved legacy asymmetry).
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
