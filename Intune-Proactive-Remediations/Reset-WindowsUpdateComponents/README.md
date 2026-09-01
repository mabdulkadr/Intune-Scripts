<div align="center">

# 🛡️ Reset Windows Update Components

**Intune Proactive Remediation package that resets the Windows Update cache and re-triggers update detection.**

Detection is an intentional always-trigger, and remediation stops the update services, renames `SoftwareDistribution` and `catroot2` to `.bak`, restarts everything, and fires `wuauclt /updatenow` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Reset Windows Update Components** is an Intune remediation package that gives devices a clean Windows Update state when the update stack is stuck.

The detection script intentionally does not evaluate device state: it reports non-compliance on every run so Intune always invokes the paired remediation. The remediation captures running dependents of `cryptsvc`, stops `wuauserv`, `cryptsvc`, and `bits`, renames both `SoftwareDistribution` and `System32\catroot2` to `.bak` (removing any previous backups first), restarts the core services in reverse order, restores the dependents, and finally triggers a fresh detection with `wuauclt /updatenow`.

---

# ✨ Core Features

### 🔹 Always-Trigger Detection
* Preserved legacy intent — never evaluates device state
* Exits `1` on every run so the paired remediation always executes

### 🔹 Verified Remediation
* Stops running `cryptsvc` dependents plus `wuauserv` / `cryptsvc` / `bits`, restoring them afterwards
* Renames `SoftwareDistribution` and `catroot2` to `.bak` with abort-on-failure sequencing
* Triggers `wuauclt /updatenow`; emits structured JSON result output for Intune diagnostics
* Idempotent — an existing `.bak` folder is cleared before each reset

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Reset-WindowsUpdateComponents\`

---

# 📂 Project Structure

```text
Reset-WindowsUpdateComponents
│
├── detect-Reset-WindowsUpdateComponents.ps1
├── remediate-Reset-WindowsUpdateComponents.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Reset-WindowsUpdateComponents.ps1
```

### Purpose
Always-trigger detector: unconditionally requests the paired component reset.

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
remediate-Reset-WindowsUpdateComponents.ps1
```

### Purpose
Resets the Windows Update cache folders and triggers a new scan, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `wuauserv`, `cryptsvc`, and `bits` all exist before stopping anything
2. Fix: stop services, rename `SoftwareDistribution` and `catroot2` to `.bak`, restart services in reverse order, run `wuauclt /updatenow`
3. Post-verify: every executed step must have completed without failure; any failed step aborts the remaining destructive steps

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
* `<SystemDrive>\IntuneLogs\Reset-WindowsUpdateComponents\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Reset-WindowsUpdateComponents.ps1
```

### Remediation Script
```powershell
remediate-Reset-WindowsUpdateComponents.ps1
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
3. Remediation stops services, resets the cache folders, restarts services, and triggers a scan
4. Results are verified and logged

---

# 🛡 Operational Notes
* The always-trigger detection is deliberate legacy behavior — the reset runs on every remediation cycle.
* Destructive maintenance: renaming `SoftwareDistribution` and `catroot2` wipes the local update cache and download history.
* A failed step aborts the remaining destructive steps, mirroring the original single try/catch behavior.
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
