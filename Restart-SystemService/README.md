<div align="center">

# 🛡️ Restart System Service

**Intune Proactive Remediation template pair that verifies and restarts a configured Windows service.**

Detection applies the original loose rule (the service merely existing counts as compliant) and remediation forcibly restarts the service defined in `$servicename` and verifies it is running — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Restart System Service** is an Intune remediation package template for keeping one configured Windows service healthy.

The detection script queries the configured `$servicename`, increments an internal counter when it exists and again when it is running, and treats any non-zero counter as compliant — a deliberately loose rule preserved from the original template. Only a service that cannot be found triggers remediation. The remediation then runs `Restart-Service -Force` on the configured name and verifies afterwards that the service reached the `Running` state.

> **Template note:** replace the `ServiceName` placeholder in both scripts before production use.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries one service via `Get-Service` (name, not display name)
* Preserved loose counter logic: existing = compliant; running = still compliant
* Never modifies the system during detection

### 🔹 Verified Remediation
* Runs `Restart-Service -Force` on the configured service with pre-check → fix → post-verify flow
* Verifies the service reaches the `Running` state after restart
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Restart-SystemService\`

---

# 📂 Project Structure

```text
Restart-SystemService
│
├── detect-Restart-SystemService.ps1
├── remediate-Restart-SystemService.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Restart-SystemService.ps1
```

### Purpose
Checks whether the configured service exists or appears to be running. Strictly read-only.

### Logic
1. Query the configured `$servicename` via `Get-Service`
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
remediate-Restart-SystemService.ps1
```

### Purpose
Restarts the configured service with `Restart-Service -Force`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: placeholder replaced and the configured service exists
2. Fix: `Restart-Service -Force` on the configured service name
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
* `<SystemDrive>\IntuneLogs\Restart-SystemService\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Restart-SystemService.ps1
```

### Remediation Script
```powershell
remediate-Restart-SystemService.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Replace the `ServiceName` placeholder in both scripts with a real service name
2. Intune runs the **Detection Script**
3. Detection exits with code `1` when the configured service does not exist
4. Intune runs the **Remediation Script**, which restarts the service and verifies it

---

# 🛡 Operational Notes
* Template pair: the detection intentionally treats a stopped-but-existing service as compliant — tighten the logic if you need strict state enforcement.
* An unreplaced placeholder fails the remediation with exit `1` so it can never touch a real service.
* Use the service name (not the display name) in `$servicename`.
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
