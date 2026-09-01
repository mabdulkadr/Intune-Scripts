<div align="center">

# 🪟 Remove Windows Consumer Apps

**Intune Proactive Remediation package that strips targeted consumer AppX packages from all users.**

Detection matches installed packages against a fixed consumer app list (Xbox App, Xbox Game Overlay, Xbox TCUI, Solitaire Collection, Cortana) — remediation removes them for all users and de-provisions them so they do not return for new profiles.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Remove Windows Consumer Apps** is an Intune remediation package that enforces a consumer-app-free baseline on managed devices.

The detection script enumerates `Get-AppxPackage -AllUsers` and reports every installed package found in the configured `$ConsumerApps` name list, giving operators one reason line per unwanted app. The paired remediation removes each installed copy with `Remove-AppxPackage -AllUsers`, strips provisioned copies via `Remove-AppxProvisionedPackage`, and verifies by recounting — exit `1` when anything survives.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Enumerates AppX packages for all users in one pass
* Matches against the exact legacy consumer app list (five packages)
* Reports every offending package individually before remediation
* Never modifies the system during detection

### 🔹 Verified Remediation
* Per-package removal with failure tracking for installed and provisioned copies
* De-provisions packages so new user profiles never receive them
* Verifies success through a post-removal recount of targeted packages
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Remove-WindowsConsumerApps\`

---

# 📂 Project Structure

```text
Remove-WindowsConsumerApps
│
├── detect-Remove-WindowsConsumerApps.ps1
├── remediate-Remove-WindowsConsumerApps.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Remove-WindowsConsumerApps.ps1
```

### Purpose
Detects whether any targeted consumer AppX package is still installed. Strictly read-only.

### Logic
1. Enumerate installed packages with `Get-AppxPackage -AllUsers`
2. Match package names against the five-entry `$ConsumerApps` list
3. Non-compliant per package still present

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Remove-WindowsConsumerApps.ps1
```

### Purpose
Removes the targeted packages from all users and their provisioned copies, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the Appx cmdlets are available
2. Fix: `Remove-AppxPackage -AllUsers` per installed package plus `Remove-AppxProvisionedPackage` per provisioned package
3. Post-verify: recount targeted packages; require zero remaining

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
* Removal for all users and de-provisioning require elevation (SYSTEM context).

### Logging
* `<SystemDrive>\IntuneLogs\Remove-WindowsConsumerApps\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Remove-WindowsConsumerApps.ps1
```

### Remediation Script
```powershell
remediate-Remove-WindowsConsumerApps.ps1
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
2. Detection exits with code `1` targeted packages are present
3. Intune runs the **Remediation Script**
4. Remediation removes and de-provisions them, recounts, and logs results

---

# 🛡 Operational Notes
* **Removal affects all users and all future provisioning** — provisioned packages are stripped device-wide, so new profiles will not receive these apps either.
* The Cortana entry (`Microsoft.549981C3F5F10`) no longer exists on current Windows 11 builds; it is retained for fleet compatibility.
* Individual stubborn removals do not abort the run: the final recount decides success, and survivors are logged as warnings.
* Extend coverage by adding entries to `$ConsumerApps` in both scripts — keep both lists identical.
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
