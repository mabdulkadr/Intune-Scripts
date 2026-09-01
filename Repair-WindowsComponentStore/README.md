<div align="center">

# 🪟 Repair Windows Component Store

**Intune Proactive Remediation package that repairs Windows component store corruption and system file integrity violations.**

Detection checks pending-reboot indicators and runs `DISM /CheckHealth`, then remediation runs `DISM /RestoreHealth` followed by `SFC /scannow` and reports whether a reboot finalizes the repair — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair Windows Component Store** is an Intune remediation package that fixes component store corruption and system file integrity issues on managed devices.

The detection script checks the three Windows pending-reboot indicators (Component Based Servicing, Windows Update, and `PendingFileRenameOperations`) and runs `DISM /Online /Cleanup-Image /CheckHealth` to spot repairable corruption. When issues are found, Intune runs the paired remediation: `DISM /RestoreHealth` repairs the component store, `SFC /scannow` restores system file integrity, and the script reports the classic `3010` exit code when a reboot is required to finalize repairs.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Checks CBS `RebootPending`, Windows Update `RebootRequired`, and pending file rename operations
* Runs `DISM /CheckHealth` (flag inspection only — never modifies the store)
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Runs `DISM /Online /Cleanup-Image /RestoreHealth` with the original no-timeout wait
* Runs `SFC /scannow` and classifies its output (no violations / repaired / unable to fix)
* Emits structured JSON result output for Intune diagnostics; preserves legacy exit code `3010` when a reboot is pending
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-WindowsComponentStore\`

---

# 📂 Project Structure

```text
Repair-WindowsComponentStore
│
├── detect-Repair-WindowsComponentStore.ps1
├── remediate-Repair-WindowsComponentStore.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-WindowsComponentStore.ps1
```

### Purpose
Detects whether component store repair is required. Strictly read-only.

### Logic
1. Check pending-reboot registry indicators
2. Run `DISM /Online /Cleanup-Image /CheckHealth` and capture exit code plus output
3. Non-compliant when a reboot is pending, DISM exits non-zero, or output indicates repairable corruption

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-WindowsComponentStore.ps1
```

### Purpose
Repairs the component store and system files with `DISM /RestoreHealth` and `SFC /scannow`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `dism.exe` and `sfc.exe` resolve before any repair starts
2. Fix: run `DISM /RestoreHealth`; on success run `SFC /scannow` and classify its output
3. Post-verify: both steps must complete without a fatal outcome; report `3010` when a reboot is pending

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 3010 | Success — reboot required to finalize repairs |
| 1    | Failure (a repair step failed verification) |
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
* `<SystemDrive>\IntuneLogs\Repair-WindowsComponentStore\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-WindowsComponentStore.ps1
```

### Remediation Script
```powershell
remediate-Repair-WindowsComponentStore.ps1
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
2. Detection exits with code `1` when a reboot is pending or DISM reports corruption
3. Intune runs the **Remediation Script**
4. Remediation runs both repairs, verifies them, and logs results (`3010` = reboot required)

---

# 🛡 Operational Notes
* Component store repairs can take 15+ minutes — schedule remediations accordingly.
* A reboot may be required after repairs; exit code `3010` signals this without failing the remediation.
* If SFC reports it could not fix some files, review `CBS.log` on the device.
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
