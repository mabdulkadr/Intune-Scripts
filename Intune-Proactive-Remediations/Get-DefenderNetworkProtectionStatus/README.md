<div align="center">

# 🔒 Get Defender Network Protection Status

**Intune Proactive Remediation package that enforces Microsoft Defender Network Protection in block mode.**

Detection verifies `EnableNetworkProtection = 1`, and remediation applies `Set-MpPreference -EnableNetworkProtection Enabled` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Defender Network Protection Status** is an Intune remediation package that keeps Microsoft Defender Network Protection enabled across managed devices.

Network Protection blocks outbound connections to low-reputation domains, phishing sites, and malicious content hosted on the internet at the OS network stack level. The detection script reads Defender preferences read-only and treats the device as compliant when `EnableNetworkProtection` equals `1` (block mode). When it differs, Intune runs the paired remediation that enables the feature and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `EnableNetworkProtection` from `Get-MpPreference`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Runs `Set-MpPreference -EnableNetworkProtection Enabled` with a pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Get-DefenderNetworkProtectionStatus\`

---

# 📂 Project Structure

```text
Get-DefenderNetworkProtectionStatus
│
├── detect-Get-DefenderNetworkProtectionStatus.ps1
├── remediate-Get-DefenderNetworkProtectionStatus.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Get-DefenderNetworkProtectionStatus.ps1
```

### Purpose
Verifies that Defender Network Protection is enabled. Strictly read-only.

### Logic
1. Read Microsoft Defender preferences via `Get-MpPreference`
2. Compliant when `EnableNetworkProtection = 1`
3. Non-compliant when the value differs; unexpected query failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Get-DefenderNetworkProtectionStatus.ps1
```

### Purpose
Enables Network Protection by setting `EnableNetworkProtection` to `Enabled`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm Defender preferences can be read
2. Fix: `Set-MpPreference -EnableNetworkProtection Enabled`
3. Post-verify: re-read `EnableNetworkProtection` against the expected value (`1`)

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
* `<SystemDrive>\IntuneLogs\Get-DefenderNetworkProtectionStatus\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Get-DefenderNetworkProtectionStatus.ps1
```

### Remediation Script
```powershell
remediate-Get-DefenderNetworkProtectionStatus.ps1
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
2. Detection exits with code `1` when Network Protection is not enabled
3. Intune runs the **Remediation Script**
4. Remediation enables the feature, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* **Impact warning:** in block mode Network Protection prevents access to flagged malicious/phishing destinations; pilot first and monitor Microsoft Defender event logs (`Event ID 5007`) plus end-user feedback for false positives.
* Third-party antivirus products can make `Get-MpPreference` unavailable; such environments will report detection errors as exit `2`.
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
