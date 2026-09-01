<div align="center">

# 🪟 Clear Recycle Bin

**Intune Proactive Remediation package that empties the Windows Recycle Bin on every schedule cycle.**

Detection intentionally always requests remediation and remediation runs `Clear-RecycleBin -Force` with a direct-deletion fallback — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Clear Recycle Bin** is an Intune remediation package that keeps the Windows Recycle Bin empty across managed devices.

This is an always-run maintenance package by design: detection never reports compliant, so Intune invokes the paired remediation on every schedule cycle. The remediation first runs `Clear-RecycleBin -Force`; if items remain afterward it falls back to deleting `$Recycle.Bin` contents directly on every filesystem drive, then verifies the bin is truly empty before reporting success.

---

# ✨ Core Features

### 🔹 Always-Run Detection
* Intentionally reports non-compliant so cleanup executes on every schedule cycle
* Read-only — never modifies the system during detection
* Detection errors exit `2` so Intune never treats a crash as non-compliance

### 🔹 Verified Remediation
* Primary pass runs `Clear-RecycleBin -Force` exactly as before; fallback deletes SID-folder contents directly
* Pre-check → fix → post-verify flow that re-enumerates real bin content before declaring success
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Clear-RecycleBin\`

---

# 📂 Project Structure

```text
Clear-RecycleBin
│
├── detect-Clear-RecycleBin.ps1
├── remediate-Clear-RecycleBin.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Clear-RecycleBin.ps1
```

### Purpose
Scheduled-maintenance trigger — intentionally always non-compliant. Strictly read-only.

### Logic
1. Adds an unconditional "scheduled maintenance cleanup is due" reason on every evaluation
2. Non-compliant by design so Intune runs the paired remediation every cycle
3. Exit 2 is reserved for unexpected script errors

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Clear-RecycleBin.ps1
```

### Purpose
Empties the Recycle Bin on all volumes, using a pre-check → fix → post-verify flow with a fallback deletion pass and structured JSON output.

### Logic
1. Pre-check: confirm at least one filesystem drive exists and enumerate accessible `$Recycle.Bin` roots
2. Fix: run `Clear-RecycleBin -Force`; when items remain, delete each SID folder's children directly per root
3. Post-verify: re-enumerate recycle bin contents and confirm nothing remains

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
* `<SystemDrive>\IntuneLogs\Clear-RecycleBin\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Clear-RecycleBin.ps1
```

### Remediation Script
```powershell
remediate-Clear-RecycleBin.ps1
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
2. Detection exits with code `1` by design on every schedule cycle
3. Intune runs the **Remediation Script**
4. Remediation empties the bin (cmdlet pass, fallback if needed), verifies, and logs results

---

# 🛡 Operational Notes
* **DESTRUCTIVE:** emptied Recycle Bin content is permanently deleted for all users on the device.
* Always-run design — detection deliberately never exits `0`, so expect remediation to execute on every cycle.
* An already-empty bin exits `0` without changes; the direct-deletion fallback only triggers when the cmdlet leaves items behind.
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
