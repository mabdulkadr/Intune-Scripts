<div align="center">

# 🔐 Bitlocker-EncryptionMethod

**Custom Compliance discovery script for BitLocker encryption method**

Returns JSON with BitLocker encryption method for Custom Compliance policies. Checks all BitLocker volumes for XTS-AES 128/256 per Microsoft hardening guidance.

[![Intune](https://img.shields.io/badge/Intune-Custom%20Compliance-10B981?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-scripts-included) • [Requirements](#-requirements) • [Deployment](#-intune-deployment) • [License](#-license)

</div>

---

# 🔐 Overview

**Bitlocker-EncryptionMethod** is an Intune Custom Compliance discovery script that flags devices using non-XTS (AES-CBC) encryption methods, enabling Conditional Access gating. Custom compliance scripts are always detection-only — the companion JSON file is the rulebook; the discovery script reports; the tenant decides.

---

# ✨ Core Features

### 🔹 XTS-AES Enforcement
* Custom Compliance discovery that flags devices using non-XTS (AES-CBC) encryption methods, enabling Conditional Access gating.
### 🔹 JSON Discovery Output
* Returns {BitLockerEncryptionMethod, Compliant} for Intune to evaluate against the companion JSON rules file.

---

# 📂 Project Structure

```text
Bitlocker-EncryptionMethod
│
├── Get-BitlockerEncryptionMethodCompliance.ps1
├── Bitlocker-EncryptionMethod.json
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**
`powershell
Get-BitlockerEncryptionMethodCompliance.ps1
`

### Purpose
Discovery script - returns JSON with BitLocker encryption method for Custom Compliance policies. Always exits 0 (compliance is evaluated by the JSON rules).

### Output
`json
{"BitLockerEncryptionMethod":"XTS-AES 256","Compliant":true,"Details":["Volume C:: XTS-AES 256 (Compliant=True)"]}
`

## 🛠 Remediation Script

**File**
`powershell
# Custom Compliance discovery scripts do not require a paired remediation script.
# Intune enforces compliance via Conditional Access policy - non-compliant devices are blocked.
# Use a separate Intune Configuration Profile to push the desired encryption method, e.g.:
#   ./Vendor/MSFT/BitLocker/GroupPolicy:"EncryptionMethodWithXtsAes256"
`

### Purpose
Custom Compliance is a read-only evaluation surface. When a device is non-compliant, the operator must remediate via a separate Intune Configuration Profile (BitLocker policy) or a Win32 LOB app. No in-script remediation is performed.

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Discovery completed (compliance evaluated by Intune) |
| 2    | Script error |

---

# ⚙ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context as a discovery script.

### Logging
* No local log file (custom compliance discovery scripts log to Intune).

---

# 🛭 Intune Deployment

### Detection Script
`powershell
Get-BitlockerEncryptionMethodCompliance.ps1
`

### Remediation Script
`powershell
# Custom compliance discovery has no paired remediation.
# Pair with a separate BitLocker Configuration Profile that sets XTS-AES 256.
`

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Upload Get-BitlockerEncryptionMethodCompliance.ps1 to **Devices > Compliance > Scripts**
2. Create compliance policy > **Custom Compliance** > Require > Select script
3. Upload Bitlocker-EncryptionMethod.json as the rules file
4. Assign to device group; non-compliant devices are blocked by Conditional Access

---

# 🛡 Operational Notes
* Pair with the companion Bitlocker-EncryptionMethod.json rules file
* Non-compliant devices are blocked by Conditional Access if configured

---

## 👤 Author

**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

---

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