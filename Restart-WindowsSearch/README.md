<div align="center">

# 🛡️ Restart Windows Search

**Intune Proactive Remediation package that restarts the Windows Search service and verifies it recovers.**

Detection applies the original permissive rule (the `WSearch` service merely existing counts as compliant) and remediation forcibly restarts it and verifies the service returns to a running state — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Restart Windows Search** is an Intune remediation package that recovers a stuck Windows Search experience on managed devices.

The detection script queries the `WSearch` service, increments an internal counter when it exists and again when it is running, and treats any non-zero counter as compliant — a deliberately permissive rule preserved from the original script. Only a missing service triggers remediation. The remediation confirms the service exists, runs `Restart-Service -Force`, reads the service again, and verifies it reached the `Running` state before reporting success.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries the `WSearch` service via `Get-Service`
* Preserved permissive counter logic: existing = compliant; running = still compliant
* Never modifies the system during detection

### 🔹 Verified Remediation
* Runs `Restart-Service -Force` on `WSearch` with a pre-check → fix → post-verify flow
* Verifies the service reaches the `Running` state after restart
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Restart-WindowsSearch\`

---

# 📂 Project Structure

```text
Restart-WindowsSearch
│
├── detect-Restart-WindowsSearch.ps1
├── remediate-Restart-WindowsSearch.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Restart-WindowsSearch.ps1
```

### Purpose
Checks whether the Windows Search service exists or appears to be running. Strictly read-only.

### Logic
1. Query the `WSearch` service via `Get-Service`
2. Counter increments when the service exists and again when it is running
3. Non-compliant only when the service cannot be found (counter stays zero)

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Restart-WindowsSearch.ps1
```

### Purpose
Restarts Windows Search with `Restart-Service -Force`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the `WSearch` service exists (missing service fails the remediation)
2. Fix: `Restart-Service -Force` on `WSearch`
3. Post-verify: re-read the service status and require the `Running` state

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
* `<SystemDrive>\IntuneLogs\Restart-WindowsSearch\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Restart-WindowsSearch.ps1
```

### Remediation Script
```powershell
remediate-Restart-WindowsSearch.ps1
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
2. Detection exits with code `1` when the `WSearch` service does not exist
3. Intune runs the **Remediation Script**, which restarts the service and verifies it
4. Results are logged with structured JSON output for diagnostics

---

# 🛡 Operational Notes
* The permissive detection is deliberate legacy behavior — a stopped-but-existing service stays compliant; tighten the logic if strict enforcement is required.
* Restarting Windows Search briefly interrupts search indexing and Start Menu/Cortana search results.
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
