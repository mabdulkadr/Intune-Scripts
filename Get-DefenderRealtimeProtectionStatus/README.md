<div align="center">

# 🛡️ Get Defender Realtime Protection Status

**Intune Proactive Remediation package that keeps Microsoft Defender real-time protection enabled.**

Detection verifies that `RealTimeProtectionEnabled` is reported as `True` via `Get-MpComputerStatus` and remediation re-enables it with `Set-MpPreference -DisableRealtimeMonitoring $false` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Defender Realtime Protection Status** is an Intune remediation package that keeps Microsoft Defender real-time protection enabled across managed devices.

Real-time protection is the core on-access scanning layer of Microsoft Defender that inspects file and process activity the moment it happens. When third-party tools, tampering, or misconfigured images turn it off, endpoints lose their primary malware defense. The detection script reads the status read-only; when real-time protection is disabled (or the status cannot be verified), Intune runs the paired remediation that re-enables it and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `RealTimeProtectionEnabled` from `Get-MpComputerStatus`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Runs `Set-MpPreference -DisableRealtimeMonitoring $false` with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Get-DefenderRealtimeProtectionStatus\`

---

# 📂 Project Structure

```text
Get-DefenderRealtimeProtectionStatus
│
├── detect-Get-DefenderRealtimeProtectionStatus.ps1
├── remediate-Get-DefenderRealtimeProtectionStatus.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Get-DefenderRealtimeProtectionStatus.ps1
```

### Purpose
Verifies that Microsoft Defender real-time protection is enabled. Strictly read-only.

### Logic
1. Query `Get-MpComputerStatus`
2. Compliant when `RealTimeProtectionEnabled` equals `True`
3. Non-compliant when it is anything else; unexpected query failures exit with code `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Get-DefenderRealtimeProtectionStatus.ps1
```

### Purpose
Enables real-time protection by running `Set-MpPreference -DisableRealtimeMonitoring $false`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `Set-MpPreference` is available and capture the current status
2. Fix: `Set-MpPreference -DisableRealtimeMonitoring $false`
3. Post-verify: re-query `Get-MpComputerStatus` and confirm `RealTimeProtectionEnabled = True`

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
* `<SystemDrive>\IntuneLogs\Get-DefenderRealtimeProtectionStatus\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Get-DefenderRealtimeProtectionStatus.ps1
```

### Remediation Script
```powershell
remediate-Get-DefenderRealtimeProtectionStatus.ps1
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
2. Detection exits with code `1` when real-time protection is disabled
3. Intune runs the **Remediation Script**
4. Remediation applies the setting, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* If tamper protection blocks the preference change, verification fails and the script exits `1`; investigate protection policies rather than rerunning blindly.
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
