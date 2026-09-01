<div align="center">

# 🧹 Invoke Disk Cleanup

**Intune Proactive Remediation package that reclaims disk space from temp folders and the Recycle Bin.**

Detection measures cleanable space and remediation clears it when the 1 GB threshold is exceeded.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke Disk Cleanup** measures recoverable space in `C:\Windows\Temp`, each user's `AppData\Local\Temp`, and the Recycle Bin. When the total exceeds **1 GB**, detection returns non-compliant and Intune runs the remediation that clears those locations.

Detection is strictly read-only; remediation performs the deletions and verifies the result with structured JSON output.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Recursively measures `C:\Windows\Temp` and per-user temp folders
* Includes Recycle Bin size via Shell.Application
* Never deletes anything during detection

### 🔹 Verified Remediation
* Clears Windows Temp, user Temps, and empties Recycle Bin (pre-check → fix → post-verify)
* Emits structured JSON result
* Idempotent — safe on every run

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines
* Written to `<SystemDrive>\IntuneLogs\Invoke-DiskCleanup\` (legacy folder `disk-cleanup` also supported)

---

# 📂 Project Structure

```text
Invoke-DiskCleanup
│
├── detect-Invoke-DiskCleanup.ps1
├── remediate-Invoke-DiskCleanup.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Invoke-DiskCleanup.ps1
```

### Purpose
Measures cleanable space and reports compliance against the 1 GB threshold. Read-only.

### Logic
1. `Get-FolderSize` on `C:\Windows\Temp` and each `C:\Users\*\AppData\Local\Temp`
2. Sum Recycle Bin items via `Shell.Application`
3. Compliant when total ≤ 1 GB; non-compliant otherwise

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Compliant (cleanable space below threshold) |
| 1 | Non-compliant (triggers remediation) |
| 2 | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Invoke-DiskCleanup.ps1
```

### Purpose
Clears temp folders and Recycle Bin when detection flagged excess space.

### Logic
1. Pre-check: measure cleanable space (same as detection)
2. Fix: `Remove-Item` on temp paths + `Clear-RecycleBin` via COM
3. Post-verify: re-measure and emit JSON

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success (space reclaimed and verified) |
| 1 | Failure (verification failed) |
| 2 | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required. SYSTEM can enumerate all user temp folders.

### Logging
* `<SystemDrive>\IntuneLogs\Invoke-DiskCleanup\` (and legacy `disk-cleanup`)

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Invoke-DiskCleanup.ps1
```

### Remediation Script
```powershell
remediate-Invoke-DiskCleanup.ps1
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
2. Detection exits `1` when cleanable space > 1 GB
3. Intune runs the **Remediation Script**
4. Remediation clears temps, verifies, and logs results

---

# 🛡 Operational Notes
* Threshold is `1GB` — adjust `$threshold` in both scripts if a different limit is needed (keep them in sync).
* Remediation deletes temp files aggressively; test on a pilot group first.
* Detection handles unreadable paths as 0 bytes and continues.
* Detection errors exit `2` so Intune never treats a crash as non-compliance.

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
