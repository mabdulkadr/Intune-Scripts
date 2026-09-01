<div align="center">

# 🧰 Remove Dell SupportAssist

**Intune Proactive Remediation package that removes Dell SupportAssist from managed devices.**

Detection searches the standard uninstall registry locations for an application named exactly `Dell SupportAssist` and remediation uninstalls it using the removal method advertised in its own registry entry — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Remove Dell SupportAssist** is an Intune remediation package that detects and uninstalls the Dell SupportAssist application across managed devices.

Dell SupportAssist frequently ships pre-installed on consumer and commercial devices, and many enterprise baselines require third-party OEM support tooling to be removed. The detection script queries the standard 64-bit and 32-bit HKLM uninstall keys read-only; when an entry named `Dell SupportAssist` is found, Intune runs the paired remediation, which resolves the entry's uninstall string and launches the matching silent uninstaller (`msiexec.exe` with the extracted product GUID, or `SupportAssistUninstaller.exe /arp /S`), then verifies the entry is gone.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall` and its `Wow6432Node` counterpart
* Matches the display name exactly against `Dell SupportAssist`
* Reports the discovered `UninstallString` so remediation reuses the vendor's own removal method

### 🔹 Verified Remediation
* Resolves the supported silent uninstall command from the uninstall string (MSI GUID or SupportAssist uninstaller) with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — a device without the application exits successfully without changes

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Uninstall-DellSupportAssistApp\`

---

# 📂 Project Structure

```text
Uninstall-DellSupportAssistApp
│
├── detect-Uninstall-DellSupportAssistApp.ps1
├── remediate-Uninstall-DellSupportAssistApp.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Uninstall-DellSupportAssistApp.ps1
```

### Purpose
Verifies that Dell SupportAssist is not installed. Strictly read-only.

### Logic
1. Query the standard 64-bit and 32-bit HKLM uninstall registry locations
2. Compliant when no entry named `Dell SupportAssist` exists
3. Non-compliant when the entry is found; the reason includes its `UninstallString`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Uninstall-DellSupportAssistApp.ps1
```

### Purpose
Uninstalls Dell SupportAssist using the removal method advertised in its registry entry, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the uninstall registry keys are readable and resolve the target entry
2. Fix: launch the resolved silent uninstaller (`msiexec.exe /x {GUID} /qn /norestart`, or `SupportAssistUninstaller.exe /arp /S`) and wait for completion
3. Post-verify: re-query the uninstall registry and confirm the entry is gone

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
* `<SystemDrive>\IntuneLogs\Uninstall-DellSupportAssistApp\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Uninstall-DellSupportAssistApp.ps1
```

### Remediation Script
```powershell
remediate-Uninstall-DellSupportAssistApp.ps1
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
2. Detection exits with code `1` when a `Dell SupportAssist` installation is found
3. Intune runs the **Remediation Script**
4. Remediation launches the silent uninstaller, verifies the entry is gone, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* Dell SupportAssist is OEM-supported software — removing it may affect Dell warranty checks, driver update prompts, and diagnostic tooling; make sure removal aligns with your OEM support strategy.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.
* Uninstallers can return non-zero codes for transient reasons (pending reboot, running processes); review the log file before re-running.

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
