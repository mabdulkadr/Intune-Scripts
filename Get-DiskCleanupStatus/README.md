<div align="center">

# 🩺 Get Disk Cleanup Status

**Intune Proactive Remediation package that reclaims disk space on devices running low on free storage.**

Detection watches free space on drive `C:` and, once it drops below `15` GB, Intune runs the remediation that configures the selected Disk Cleanup handlers and launches `CleanMgr.exe /sagerun:1` — keeping managed fleets installable and healthy.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Disk Cleanup Status** is an Intune remediation package that frees storage automatically when devices run low on disk space.

Low free space blocks Windows updates, feature installs, and profile operations. The detection script reads drive `C:` free space via `Get-PSDrive` read-only; when it falls below the threshold (`StorageThresholdGB = 15`), Intune runs the paired remediation, which writes `StateFlags0001 = 2` for the selected VolumeCaches handlers (`Temporary Sync Files`, `Downloaded Program Files`, `Memory Dump Files`, `Recycle Bin`) and runs `CleanMgr.exe /sagerun:1` to completion.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads free space of drive `C:` from `Get-PSDrive`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Configures each cleanup handler with a pre-check → per-handler fix → post-verify flow
* Runs `CleanMgr.exe /sagerun:1` synchronously and tracks per-target failures
* Emits structured JSON result output for Intune diagnostics; idempotent

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Get-DiskCleanupStatus\`

---

# 📂 Project Structure

```text
Get-DiskCleanupStatus
│
├── detect-Get-DiskCleanupStatus.ps1
├── remediate-Get-DiskCleanupStatus.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Get-DiskCleanupStatus.ps1
```

### Purpose
Checks whether free space on drive `C:` is below the configured threshold. Strictly read-only.

### Logic
1. Read free space from `Get-PSDrive -Name C`
2. Compliant while free space is at or above `15` GB
3. Non-compliant below the threshold; unexpected query failures exit with code `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Get-DiskCleanupStatus.ps1
```

### Purpose
Configures the selected Disk Cleanup handlers and runs `CleanMgr.exe`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the `VolumeCaches` registry key and `cleanmgr.exe` exist
2. Fix: set `StateFlags0001 = 2` (DWORD) per handler present on the device, then launch `CleanMgr.exe /sagerun:1` and wait
3. Post-verify: re-read each handler's `StateFlags0001` and confirm it equals `2`; the space reclaimed depends on what Windows finds to clean

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

### Logging
* `<SystemDrive>\IntuneLogs\Get-DiskCleanupStatus\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Get-DiskCleanupStatus.ps1
```

### Remediation Script
```powershell
remediate-Get-DiskCleanupStatus.ps1
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
2. Detection exits with code `1` when free space drops below the threshold
3. Intune runs the **Remediation Script**
4. Remediation configures handlers, runs Disk Cleanup, verifies flags, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already above the threshold exit `0` without changes.
* Handlers missing on a given image are skipped with a warning instead of failing the run.
* Verification proves the handler configuration persisted and CleanMgr completed; actual gigabytes reclaimed vary per device.
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
