<div align="center">

# 🛡️ Install DotNetFramework35

**Intune Proactive Remediation package that keeps the .NET Framework 3.5 (NetFx3) optional feature enabled.**

Detection checks the local NetFx3 state via `Get-WindowsOptionalFeature` and remediation enables it with `Enable-WindowsOptionalFeature -All -NoRestart` — keeping legacy line-of-business applications installable across the fleet.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Install DotNetFramework35** is an Intune remediation package that enables the .NET Framework 3.5 Windows optional feature on managed devices.

Many legacy applications still require .NET 3.5, which Windows ships disabled by default. The detection script queries `NetFx3` via `Get-WindowsOptionalFeature` read-only (and appends a support transcript to `%TEMP%\NetFx3.log`, preserving legacy behavior); when the feature is not `Enabled`, Intune runs the paired remediation that installs it with `-All -NoRestart` and verifies the resulting state.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads the `NetFx3` feature state from `Get-WindowsOptionalFeature -Online`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Runs `Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart` with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Install-DotNetFramework35\`

---

# 📂 Project Structure

```text
Install-DotNetFramework35
│
├── detect-Install-DotNetFramework35.ps1
├── remediate-Install-DotNetFramework35.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Install-DotNetFramework35.ps1
```

### Purpose
Checks whether .NET Framework 3.5 is enabled. Strictly read-only.

### Logic
1. Append a PowerShell transcript to `%TEMP%\NetFx3.log` (legacy behavior)
2. Query `Get-WindowsOptionalFeature -Online -FeatureName NetFx3`
3. Compliant when the state is `Enabled`; otherwise non-compliant, with unexpected query failures exiting code `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Install-DotNetFramework35.ps1
```

### Purpose
Enables .NET Framework 3.5, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the DISM-backed cmdlets exist and capture the current feature state
2. Fix: `Enable-WindowsOptionalFeature -Online -FeatureName NetFx3 -All -NoRestart`
3. Post-verify: re-query the feature and confirm the state equals `Enabled`

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
* `<SystemDrive>\IntuneLogs\Install-DotNetFramework35\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Install-DotNetFramework35.ps1
```

### Remediation Script
```powershell
remediate-Install-DotNetFramework35.ps1
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
2. Detection exits with code `1` when NetFx3 is not enabled
3. Intune runs the **Remediation Script**
4. Remediation enables the feature, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* The feature payload may be downloaded from Windows Update or Windows Server Update Services; ensure devices have access to a source or provide one via policy (`UseWUServer` considerations).
* No restart is forced by the scripts; some installations may still mark a pending reboot.
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
