<div align="center">

# 🛡️ Enable WinRM Service

**Intune Proactive Remediation package that enables and validates WinRM (PowerShell Remoting) across managed devices.**

Detection runs a local `Test-WSMan` probe and remediation sets the service to Automatic, starts it, enables PowerShell Remoting, then re-validates WSMan — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Enable WinRM Service** is an Intune remediation package that ensures the Windows Remote Management service is configured, running, and accepting local PowerShell Remoting on managed devices.

Fleet management tools such as remote support runbooks and configuration collection rely on WinRM being available. The detection script probes WSMan availability read-only; when WinRM does not respond, Intune runs the paired remediation that sets the service startup type to Automatic, starts it, runs `Enable-PSRemoting -Force -SkipNetworkProfileCheck`, and verifies with a localhost WSMan test.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Single `Test-WSMan` probe against the local device
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Sets WinRM to Automatic, starts it (with a 15-second status wait), and enables PowerShell Remoting using a pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Enable-WinRMService\`

---

# 📂 Project Structure

```text
Enable-WinRMService
│
├── detect-Enable-WinRMService.ps1
├── remediate-Enable-WinRMService.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Enable-WinRMService.ps1
```

### Purpose
Verifies that WinRM is enabled and responding. Strictly read-only.

### Logic
1. Run `Test-WSMan` against the local device
2. Compliant when WSMan responds successfully
3. Non-compliant when the test fails or returns no result; unexpected evaluation failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Enable-WinRMService.ps1
```

### Purpose
Enables and starts the WinRM service, turns on PowerShell Remoting, and validates local WSMan availability using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the WinRM service exists on the device
2. Fix: set the startup type to Automatic via CIM inspection, start the service if not running (`WaitForStatus`, 15-second timeout), and run `Enable-PSRemoting -Force -SkipNetworkProfileCheck`
3. Post-verify: `Test-WSMan -ComputerName localhost` must succeed

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
* `<SystemDrive>\IntuneLogs\Enable-WinRMService\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Enable-WinRMService.ps1
```

### Remediation Script
```powershell
remediate-Enable-WinRMService.ps1
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
2. Detection exits with code `1` when WinRM does not respond
3. Intune runs the **Remediation Script**
4. Remediation configures and starts WinRM, verifies WSMan, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* **Exposure warning:** enabling WinRM opens a WS-Man listener. Review firewall profiles and listener settings; `SkipNetworkProfileCheck` allows remoting on public network profiles, so confirm your endpoint policy accepts that.
* The remediation aborts safely when the WinRM service does not exist rather than attempting an impossible fix.
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
