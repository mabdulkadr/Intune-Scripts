<div align="center">

# 🛡️ Uninstall-AnyDesk

**Silent AnyDesk Removal for Intune**
Detects AnyDesk installations and leftover data, then removes them silently with a verified Intune remediation pair.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Uninstall-AnyDesk** is an Intune proactive remediation package that removes AnyDesk from managed Windows devices.

The detection script is read-only and reports non-compliant when AnyDesk is still present as a process, service, registry entry, executable, or residual folder. When detection returns exit code `1`, Intune runs the remediation script, which stops AnyDesk, invokes the documented silent removal command, cleans residual folders, and re-checks every condition before reporting success.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Checks the AnyDesk process and service
* Checks HKLM 32-bit, HKLM 64-bit, and HKCU uninstall entries
* Checks standard executable locations and residual AppData / ProgramData folders
* Never modifies the system; logs reasons for every finding

### 🔹 Silent, Verified Removal
* Uses the documented `--silent --remove` switches instead of the interactive `--uninstall` wizard
* Stops processes and the background service before removal
* Re-runs the detection conditions after the change and only exits `0` when all artifacts are gone

### 🔹 Enterprise Standard Structure
* Canonical header with `.REMEDIATIONTYPE`, `.PAIRSCRIPT`, and the `0/1/2` exit contract
* Self-contained canonical logging in both scripts — no external helper files on the endpoint
* Structured JSON result output from remediation for Intune diagnostics

---

# 📂 Project Structure

```text
Uninstall-AnyDesk
│
├── detect-Uninstall-AnyDesk.ps1
├── remediate-Uninstall-AnyDesk.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Uninstall-AnyDesk.ps1
```

### Purpose
Read-only compliance check for AnyDesk presence. It never modifies the system.

### Logic
1. Check for a running AnyDesk process and the AnyDesk service
2. Enumerate uninstall entries under HKLM (32-bit and 64-bit) and HKCU
3. Check standard AnyDesk.exe locations under Program Files and local AppData
4. Check residual AnyDesk folders under AppData and ProgramData
5. Return exit `0` when no artifact is found, otherwise log and output every reason and return exit `1`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Uninstall-AnyDesk.ps1
```

### Purpose
Silently removes AnyDesk and its residual data, then verifies the outcome with the same conditions the detector uses.

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
* `<SystemDrive>\IntuneLogs\UninstallAnyDesk\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Uninstall-AnyDesk.ps1
```

### Remediation Script
```powershell
remediate-Uninstall-AnyDesk.ps1
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
2. Detection exits with code `0` when AnyDesk is absent, or `1` when artifacts are found
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation stops AnyDesk, runs the silent uninstaller, removes residual folders, verifies, and logs the result

---

# 🛡 Operational Notes

* Residual cleanup permanently deletes the device AnyDesk ID and Alias. They cannot be restored after removal.
* Detection in SYSTEM context covers machine-wide artifacts and the SYSTEM hive. A per-user installation registered only in another user's HKCU is not visible here; use the standalone manual script with logged-on credentials for that case.
* `--remove` with `--silent` is the documented unattended switch. `--uninstall` opens a graphical wizard and can hang an automated run.
* Both scripts are idempotent: running detection again after a successful remediation returns exit `0`.
* A script error exits `2` so Intune never treats a crash as non-compliance.
* Each half of the pair embeds its own logging helpers, so no additional files need to be deployed.

---

## 👤 Author

**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

---

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

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin)

</div>
