<div align="center">

# 🧰 Uninstall Microsoft Teams Personal

**Intune Proactive Remediation package that removes the personal (Store) Microsoft Teams AppX package.**

Detection enumerates AppX packages for all users looking for `MicrosoftTeams` and remediation removes every discovered instance with `Remove-AppxPackage` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Uninstall Microsoft Teams Personal** is an Intune remediation package that removes the Store/AppX form of the Teams personal client across managed devices.

Organizations that standardize on enterprise messaging clients frequently want the consumer Teams preview gone from user-facing devices. The detection script runs `Get-AppxPackage -Name MicrosoftTeams -AllUsers` read-only; when any instance exists, Intune runs the paired remediation, which removes each discovered package — preferring the `-AllUsers` parameter when the cmdlet supports it — and then verifies no instance remains. The new Teams client (`MSTeams`) is not evaluated or touched by this pair.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Enumerates AppX packages for all users via `Get-AppxPackage -Name MicrosoftTeams -AllUsers`
* Reports the number of discovered instances
* Never modifies the system during detection

### 🔹 Verified Remediation
* Per-package removal with failure tracking and pre-check → fix → post-verify flow
* Uses `Remove-AppxPackage -AllUsers` where supported, falling back to per-package removal
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Uninstall-MicrosoftTeamsPersonal\`

---

# 📂 Project Structure

```text
Uninstall-MicrosoftTeamsPersonal
│
├── detect-Uninstall-MicrosoftTeamsPersonal.ps1
├── remediate-Uninstall-MicrosoftTeamsPersonal.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Uninstall-MicrosoftTeamsPersonal.ps1
```

### Purpose
Verifies that the MicrosoftTeams AppX package is not present for any user. Strictly read-only.

### Logic
1. Run `Get-AppxPackage -Name MicrosoftTeams -AllUsers`
2. Compliant when no instance is returned
3. Non-compliant when one or more instances exist

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Uninstall-MicrosoftTeamsPersonal.ps1
```

### Purpose
Removes every discovered MicrosoftTeams AppX instance, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `Remove-AppxPackage` is available and resolve all target packages
2. Fix: remove each package, using `-AllUsers` when the cmdlet parameter set supports it
3. Post-verify: re-run the AppX query and confirm zero instances remain

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
* `-AllUsers` queries require an elevated (SYSTEM/Administrator) context.

### Logging
* `<SystemDrive>\IntuneLogs\Uninstall-MicrosoftTeamsPersonal\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Uninstall-MicrosoftTeamsPersonal.ps1
```

### Remediation Script
```powershell
remediate-Uninstall-MicrosoftTeamsPersonal.ps1
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
2. Detection exits with code `1` when a MicrosoftTeams AppX instance exists
3. Intune runs the **Remediation Script**
4. Remediation removes each instance, verifies removal, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* Targets the Store/AppX Teams client only; the new Teams client (`MSTeams`) and the machine-wide installer are intentionally out of scope.
* Windows may reprovision removed Store apps on feature updates; keep the remediation assigned to recur.
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
