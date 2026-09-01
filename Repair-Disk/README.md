<div align="center">

# 💽 Repair Disk

**Intune Proactive Remediation package that scans the system drive file system and reports file system errors.**

Detection is an intentional always-trigger, and remediation runs an online `Repair-Volume -Scan` on the system volume and compares the output to the expected healthy token — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair Disk** is an Intune remediation package that runs a file system scan on the Windows system drive across managed devices.

The detection script intentionally does not evaluate device state: it reports non-compliance on every run so Intune always invokes the paired remediation. The remediation resolves the system drive letter, runs `Repair-Volume -Scan`, flattens the verbose scan output into one status string, and compares it against the expected healthy token `NoErrorsFound`. A match exits `0`; anything else (including scan failures) exits `1`.

---

# ✨ Core Features

### 🔹 Always-Trigger Detection
* Preserved legacy intent — never evaluates device state
* Exits `1` on every run so the paired remediation always executes

### 🔹 Verified Remediation
* Resolves the system drive letter and validates the volume before scanning
* Runs `Repair-Volume -Scan` with verbose output flattened into one comparable string
* Compares the captured output to `NoErrorsFound` using a pre-check → fix → post-check flow
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-Disk\`

---

# 📂 Project Structure

```text
Repair-Disk
│
├── detect-Repair-Disk.ps1
├── remediate-Repair-Disk.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-Disk.ps1
```

### Purpose
Always-trigger detector: unconditionally requests the paired disk repair remediation.

### Logic
1. Evaluates no device state (preserved legacy behavior)
2. Reports one non-compliance condition on every run
3. Intune therefore invokes the remediation script each cycle

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (never returned by this detector) |
| 1    | Non-compliant (always — triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-Disk.ps1
```

### Purpose
Scans the system drive file system with `Repair-Volume -Scan` and verifies the output against the healthy token, using a pre-check → fix → post-check flow with structured JSON output.

### Logic
1. Pre-check: resolve the system drive letter and confirm the volume exists
2. Fix: run `Repair-Volume -Scan` and flatten verbose records into one status string (`No scan output was returned.` when empty)
3. Post-check: compare the captured output to `NoErrorsFound`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (scan output matched the healthy token) |
| 1    | Failure (scan reported issues or failed) |
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
* `<SystemDrive>\IntuneLogs\Repair-Disk\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-Disk.ps1
```

### Remediation Script
```powershell
remediate-Repair-Disk.ps1
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
2. Detection always exits with code `1`, so Intune runs the **Remediation Script**
3. Remediation scans the system drive with `Repair-Volume -Scan`
4. The captured output is compared to `NoErrorsFound` and results are logged

---

# 🛡 Operational Notes
* The always-trigger detection is deliberate legacy behavior — every device is scanned on every remediation cycle.
* Online volume scans can take several minutes on large drives; plan remediation schedules accordingly.
* Scan failures surface as exit `1` so operators see them as device health failures.
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
