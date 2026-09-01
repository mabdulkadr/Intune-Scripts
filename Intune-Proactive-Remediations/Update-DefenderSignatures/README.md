<div align="center">

# 🛡️ Update Defender Signatures

**Intune Proactive Remediation package that keeps Windows Defender antivirus definitions current.**

Detection checks signature age and remediation forces `Update-MpSignature` when definitions are older than 48 hours.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Update Defender Signatures** ensures Windows Defender antivirus definitions are not stale.

The detection script calls `Get-MpComputerStatus` and compares `AntivirusSignatureLastUpdated` against the current time. When the age exceeds **48 hours** (`$MaxDefinitionAgeHours`), detection returns non-compliant and Intune runs the remediation that executes `Update-MpSignature` and verifies the result.

Detection is strictly read-only.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* `Get-MpComputerStatus` with typed `CommandNotFoundException` handling
* Computes definition age in hours and logs version + timestamp
* Never triggers an update during detection

### 🔹 Verified Remediation
* `Update-MpSignature` with pre-check → fix → post-verify
* Emits structured JSON result for Intune diagnostics
* Idempotent — current definitions exit `0` without changes

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines
* Written to `<SystemDrive>\IntuneLogs\Update-DefenderSignatures\` (legacy `antivirus-definition-updates`)

---

# 📂 Project Structure

```text
Update-DefenderSignatures
│
├── detect-Update-DefenderSignatures.ps1
├── remediate-Update-DefenderSignatures.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Update-DefenderSignatures.ps1
```

### Purpose
Reports whether Defender definitions are current. Read-only.

### Logic
1. `Get-MpComputerStatus` (throws typed error if module missing)
2. Compute `(Get-Date) - AntivirusSignatureLastUpdated` in hours
3. Compliant when age ≤ 48 hours; non-compliant otherwise

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Compliant (definitions current) |
| 1 | Non-compliant (triggers remediation) |
| 2 | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Update-DefenderSignatures.ps1
```

### Purpose
Forces a Defender signature update when detection flagged outdated definitions.

### Logic
1. Pre-check: read current definition age
2. Fix: `Update-MpSignature -ErrorAction Stop`
3. Post-verify: re-read `Get-MpComputerStatus` and confirm age ≤ threshold; emit JSON

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success (signatures updated and verified) |
| 1 | Failure (update did not reduce age) |
| 2 | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 with Microsoft Defender enabled

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required. `Get-MpComputerStatus`/`Update-MpSignature` require the Defender platform.

### Logging
* `<SystemDrive>\IntuneLogs\Update-DefenderSignatures\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Update-DefenderSignatures.ps1
```

### Remediation Script
```powershell
remediate-Update-DefenderSignatures.ps1
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
2. Detection exits `1` when definition age > 48 hours
3. Intune runs the **Remediation Script**
4. Remediation runs `Update-MpSignature`, verifies, and logs JSON result
5. Next detection run reports compliant when signatures are current

---

# 🛡 Operational Notes
* Threshold is `48` hours (`$MaxDefinitionAgeHours`) — keep it in sync between both scripts.
* Devices with Defender disabled or `Get-MpComputerStatus` missing will exit `2` (error, not non-compliance).
* Remediation requires network access to the definition update source.
* Detection errors exit `2` so a crash is never treated as non-compliance.
* Test on a pilot group; frequent definition updates are normal but verify after a forced update.

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
