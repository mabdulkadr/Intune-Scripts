<div align="center">

# 🪟 Restart Windows Update

**Intune Proactive Remediation package that keeps the Windows Update service (wuauserv) available and running.**

Detection verifies that the `wuauserv` service exists and remediation restarts it with `Restart-Service -Force` until it reports `Running` — built for enterprise fleet maintenance.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Restart Windows Update** is an Intune remediation package that restores the Windows Update service on managed devices.

The Windows Update service (`wuauserv`) is a common casualty of broken update stacks and aggressive cleanup tools. The detection script queries the service read-only and preserves the original permissive rule: a service that merely exists satisfies the check, while a stopped-but-present service is logged as a warning but stays compliant. Only a missing service triggers remediation, which restarts the service and verifies it reports `Running`.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries the `wuauserv` service via `Get-Service`
* Never modifies the system during detection
* Preserves the legacy permissive rule: existing service = compliant, stopped state logged as warning only

### 🔹 Verified Remediation
* Restarts `wuauserv` with `Restart-Service -Force` using a pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Restart-WindowsUpdate\`

---

# 📂 Project Structure

```text
Restart-WindowsUpdate
│
├── detect-Restart-WindowsUpdate.ps1
├── remediate-Restart-WindowsUpdate.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Restart-WindowsUpdate.ps1
```

### Purpose
Verifies that the Windows Update service exists. Strictly read-only.

### Logic
1. Query `wuauserv` via `Get-Service`
2. Compliant when the service exists (running or stopped — permissive legacy rule)
3. Non-compliant when the service cannot be found

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Restart-WindowsUpdate.ps1
```

### Purpose
Restarts the Windows Update service so it returns to `Running`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `wuauserv` exists before touching anything
2. Fix: `Restart-Service -Name wuauserv -Force`
3. Post-verify: query the service again and require `Status = Running`

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
* `<SystemDrive>\IntuneLogs\Restart-WindowsUpdate\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Restart-WindowsUpdate.ps1
```

### Remediation Script
```powershell
remediate-Restart-WindowsUpdate.ps1
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
2. Detection exits with code `1` when `wuauserv` is missing
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation restarts the service, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* A present-but-stopped service is intentionally treated as compliant (legacy behavior preserved); the state is logged as a warning for troubleshooting.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.
* `Restart-Service -Force` also restarts dependent services if any exist.

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
