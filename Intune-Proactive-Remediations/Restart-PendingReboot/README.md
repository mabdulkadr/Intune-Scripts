<div align="center">

# 🔄 Restart Pending Reboot

**Intune Proactive Remediation package that flags devices with a pending reboot and schedules a graceful restart.**

Detection checks Component Based Servicing, Windows Update, pending file renames and pending computer rename, gated by a minimum uptime threshold.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Restart Pending Reboot** detects the standard Windows pending-reboot signals and, when the device has been up longer than the configured threshold, triggers the paired remediation that schedules a restart with user warning.

Signals inspected:
* `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending`
* `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired`
* `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\PendingFileRenameOperations`
* Pending computer rename (`ActiveComputerName` vs `ComputerName`)

`PendingFileRenameOperations` alone is noisy, so it only counts when uptime exceeds `$MinimumUptimeDays` (default **2 days**). Detection is read-only; remediation schedules the reboot.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Checks all four pending-reboot registry locations
* Gates on uptime via `Win32_OperatingSystem.LastBootUpTime`
* Never triggers a reboot during detection

### 🔹 Verified Remediation
* Schedules restart with user notification (pre-check → schedule → post-verify)
* Emits structured JSON result
* Idempotent — already-compliant or recently-rebooted devices exit `0`

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines
* Written to `<SystemDrive>\IntuneLogs\Restart-PendingReboot\` (legacy `reboot-pending`)

---

# 📂 Project Structure

```text
Restart-PendingReboot
│
├── detect-Restart-PendingReboot.ps1
├── remediate-Restart-PendingReboot.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Restart-PendingReboot.ps1
```

### Purpose
Reports whether a reboot is pending and actionable. Read-only.

### Logic
1. `Test-PendingReboot` checks the four registry signals
2. Compute uptime in days
3. Compliant when no signals, or when signals exist but uptime < `$MinimumUptimeDays`
4. Non-compliant when signals exist and uptime ≥ threshold

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Compliant (no actionable pending reboot) |
| 1 | Non-compliant (triggers remediation) |
| 2 | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Restart-PendingReboot.ps1
```

### Purpose
Schedules a system restart with user warning when detection flagged an actionable pending reboot.

### Logic
1. Pre-check: confirm pending signals + uptime ≥ threshold
2. Fix: `shutdown /r /t` with notification delay
3. Post-verify: confirm reboot was scheduled; emit JSON

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success (reboot scheduled and verified) |
| 1 | Failure (schedule failed) |
| 2 | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Restart-PendingReboot\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Restart-PendingReboot.ps1
```

### Remediation Script
```powershell
remediate-Restart-PendingReboot.ps1
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
2. Detection exits `1` when a reboot is pending and uptime ≥ 2 days
3. Intune runs the **Remediation Script**
4. Remediation schedules the restart, verifies, and logs JSON result
5. Device restarts at the scheduled time; next detection run reports compliant

---

# 🛡 Operational Notes
* `$MinimumUptimeDays` avoids flagging devices that just rebooted but picked up a new pending flag — keep it in sync between both scripts.
* `PendingFileRenameOperations` is common after installs; uptime gating prevents noise.
* Remediation uses a timed `shutdown` — user sees a notification; no forced immediate reboot.
* Detection errors exit `2` so a crash is never treated as non-compliance.
* Test on a pilot group to tune the uptime threshold for your fleet.

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
