<div align="center">

# ⚙️ Invoke GPUpdate

**Intune Proactive Remediation package that forces a Group Policy refresh on a schedule.**

Detection is an always-trigger detector that reports non-compliant on every run — remediation then runs `gpupdate /force` and verifies the command result, giving administrators a reliable Intune-driven Group Policy refresh cadence.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke GPUpdate** is an Intune remediation package that forces Group Policy refreshes across managed devices on whatever cadence the assignment defines.

This package intentionally has no real compliance condition: the detection script is an always-trigger detector (preserved by design from the legacy pair) that exits `1` on every run, so Intune always runs the paired remediation. The remediation executes `gpupdate /force`, checks the command result, and reports success or failure with structured JSON output.

---

# ✨ Core Features

### 🔹 Always-Trigger Detection
* Deliberately evaluates nothing — exits `1` on every run by design
* Documents its always-run intent in output and logs for operators
* Keeps the pair predictable: every detection cycle ends in a refresh

### 🔹 Verified Remediation
* Pre-check resolves the `gpupdate` command before invoking it
* Runs `gpupdate /force` with per-target failure tracking
* Verifies the command exit code; emits structured JSON result output
* Unexpected errors exit `2` instead of being masked as failures

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Invoke-GPUpdate\`

---

# 📂 Project Structure

```text
Invoke-GPUpdate
│
├── detect-Invoke-GPUpdate.ps1
├── remediate-Invoke-GPUpdate.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Invoke-GPUpdate.ps1
```

### Purpose
Always triggers the paired remediation. Strictly read-only — it performs no system evaluation.

### Logic
1. Report one fixed condition: "a Group Policy refresh is requested"
2. Exit `1` on every run so Intune invokes the remediation

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Invoke-GPUpdate.ps1
```

### Purpose
Forces a Group Policy refresh via `gpupdate /force`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the `gpupdate` command resolves
2. Fix: invoke `gpupdate /force`
3. Post-verify: require gpupdate exit code `0`

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
* Runs via Intune in SYSTEM or user context per assignment — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Invoke-GPUpdate\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Invoke-GPUpdate.ps1
```

### Remediation Script
```powershell
remediate-Invoke-GPUpdate.ps1
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
2. Detection exits with code `1` on every run (always-trigger design)
3. Intune always runs the **Remediation Script**
4. Remediation forces the refresh, verifies the result, and logs outcomes

---

# 🛡 Operational Notes
* Every detection cycle triggers a remediation run — scope assignments deliberately to avoid excessive Group Policy churn.
* A `gpupdate` exit code of `0` confirms the refresh was initiated; actual policy application is asynchronous.
* User-targeted policy only applies when the script runs in the interactive user context; machine policy applies in SYSTEM context.
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
