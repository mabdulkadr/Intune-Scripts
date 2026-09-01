<div align="center">

# 🔒 Get BitLocker Recovery Key Info

**Intune Proactive Remediation package that surfaces BitLocker recovery key availability for the OS volume.**

Detection verifies that the `C:` volume exposes a recovery password, and the paired remediation is intentionally informational — it re-queries BitLocker and prints the current recovery key when the volume is fully encrypted — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get BitLocker Recovery Key Info** is an Intune status/reporting package for BitLocker recoverability across managed devices.

A BitLocker volume without an escrowed or at least locally visible recovery password is a supportability risk: one forgotten PIN or corrupted TPM state away from data loss. The detection script queries `Get-BitLockerVolume -MountPoint C:` read-only and treats the device as compliant when at least one `RecoveryPassword` key protector is populated; when none exist (or encryption is incomplete), Intune runs the paired remediation, which does **not** create or rotate keys — it re-queries the volume, logs the encryption percentage, and prints the current recovery key when the OS volume is fully encrypted.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries `Get-BitLockerVolume` on `C:` and inspects `KeyProtector.RecoveryPassword`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Informational Remediation
* Re-queries BitLocker and reports the first recovery password when encryption is complete — never creates or rotates key protectors
* Emits structured JSON result output for Intune diagnostics
* Verification reflects what reporting guarantees: a queryable volume with an exposed recovery password

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Get-BitLockerRecoveryKeyInfo\`

---

# 📂 Project Structure

```text
Get-BitLockerRecoveryKeyInfo
│
├── detect-Get-BitLockerRecoveryKeyInfo.ps1
├── remediate-Get-BitLockerRecoveryKeyInfo.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Get-BitLockerRecoveryKeyInfo.ps1
```

### Purpose
Verifies that the OS volume exposes a BitLocker recovery password. Strictly read-only.

### Logic
1. Query `Get-BitLockerVolume -MountPoint 'C:'`
2. Compliant when at least one key protector has a populated `RecoveryPassword`
3. Non-compliant when no recovery password exists; unexpected query failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Get-BitLockerRecoveryKeyInfo.ps1
```

### Purpose
Informational only: re-queries BitLocker and reports the current recovery password when the volume is fully encrypted, using a pre-check → action → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the BitLocker volume on `C:` can be queried
2. Action: log the encryption percentage; print `BitLocker recovery key <password>` when fully encrypted, or emit `This script is only for reporting, no key available.` otherwise
3. Post-verify: confirm a recovery-password key protector exists right now

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (recovery password reported) |
| 1    | Failure (no key available to report) |
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
* `<SystemDrive>\IntuneLogs\Get-BitLockerRecoveryKeyInfo\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Get-BitLockerRecoveryKeyInfo.ps1
```

### Remediation Script
```powershell
remediate-Get-BitLockerRecoveryKeyInfo.ps1
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
2. Detection exits with code `1` when no recovery password is exposed
3. Intune runs the **Remediation Script**
4. Remediation re-queries BitLocker and reports the key when available, logging results

---

# 🛡 Operational Notes
* Idempotent by design — devices with an available recovery key exit `0` without changes.
* The remediation is informational and never creates or rotates BitLocker key protectors.
* **Security warning:** the recovery key is sensitive material printed to stdout and captured by Intune reporting; restrict access to device diagnostic output and prefer proper key escrow to Entra ID/AD.
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
