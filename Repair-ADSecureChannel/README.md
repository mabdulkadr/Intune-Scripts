<div align="center">

# 🌐 Repair AD Secure Channel

**Intune Proactive Remediation package that repairs a broken computer secure channel to the Active Directory domain.**

Detection verifies domain membership and tests the machine secure channel, then remediation runs `Test-ComputerSecureChannel -Repair` to restore domain trust — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair AD Secure Channel** is an Intune remediation package that detects and repairs a broken secure channel between a device and its Active Directory domain.

The machine account password can fall out of sync after snapshot restores, long offline periods, or failed domain operations. When the secure channel breaks, the device can no longer authenticate to the domain, apply Group Policy, or reach domain resources. The detection script is read-only: devices that are not domain-joined are compliant by definition (not applicable), while domain-joined devices are tested with `Test-ComputerSecureChannel`. When the test fails, Intune runs the paired remediation that repairs the channel and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `Win32_ComputerSystem` to confirm domain membership and capture the domain name
* Tests the machine secure channel with `Test-ComputerSecureChannel`
* Never modifies the system during detection; non-domain-joined devices exit `0`

### 🔹 Verified Remediation
* Repairs the secure channel with `Test-ComputerSecureChannel -Repair` using a pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device
* Optional post-repair reboot scheduling remains disabled by configuration (`$ForceRebootAfterRepair = $false`, unchanged from the legacy script)

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-ADSecureChannel\`

---

# 📂 Project Structure

```text
Repair-ADSecureChannel
│
├── detect-Repair-ADSecureChannel.ps1
├── remediate-Repair-ADSecureChannel.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-ADSecureChannel.ps1
```

### Purpose
Verifies that the computer secure channel to the domain is healthy. Strictly read-only.

### Logic
1. Query `Win32_ComputerSystem`; devices that are not domain-joined are not applicable (compliant)
2. Domain-joined devices are tested with `Test-ComputerSecureChannel`
3. Non-compliant when the secure channel test fails

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-ADSecureChannel.ps1
```

### Purpose
Repairs the machine secure channel with `Test-ComputerSecureChannel -Repair`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the device is domain-joined; non-domain-joined devices exit `0` as not applicable
2. Fix: run `Test-ComputerSecureChannel -Repair` against a writable domain controller
3. Post-verify: re-run `Test-ComputerSecureChannel` and compare against the healthy state

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
* Domain connectivity: repair requires line-of-sight to a writable domain controller.

### Logging
* `<SystemDrive>\IntuneLogs\Repair-ADSecureChannel\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-ADSecureChannel.ps1
```

### Remediation Script
```powershell
remediate-Repair-ADSecureChannel.ps1
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
2. Detection exits with code `1` when the secure channel is broken on a domain-joined device
3. Intune runs the **Remediation Script**
4. Remediation repairs the channel, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — healthy devices exit `0` without changes.
* Secure channel repair requires line-of-sight to a writable domain controller; without DC connectivity the verification fails and the script exits `1`.
* Non-domain-joined devices always exit `0` in both scripts (not applicable).
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
