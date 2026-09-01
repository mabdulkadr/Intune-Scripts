<div align="center">

# 🩺 Test PnP Device Status

**Intune Proactive Remediation package that finds and reinstalls Plug and Play devices stuck in an error state.**

Detection collects every present PnP device reporting `Status ERROR` (with optional class/ID filters) and remediation removes each one with `pnputil.exe /remove-device` then rescans hardware so Windows re-detects it cleanly.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Test PnP Device Status** is an Intune remediation package that heals broken device instances across managed fleets.

Ghosted or corrupted PnP devices show up as `Status ERROR` in `Get-PnpDevice` and can break peripherals until the instance is removed and re-detected. The detection script queries error-state devices read-only through the same include/exclude filters used by the remediation; when matches exist, Intune runs the paired remediation that removes each device with `pnputil.exe`, triggers a hardware rescan, and verifies no matching error devices remain.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries present devices with `Get-PnpDevice -PresentOnly -Status ERROR`
* Configurable wildcard include/exclude filters for device class and device ID
* Never modifies the system during detection

### 🔹 Verified Remediation
* Per-device fix flow: `pnputil.exe /remove-device <id>` followed by `/scan-devices` (original mechanism preserved)
* Pre-check → fix → post-verify with structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Test-PnPDeviceStatus\`

---

# 📂 Project Structure

```text
Test-PnPDeviceStatus
│
├── detect-Test-PnPDeviceStatus.ps1
├── remediate-Test-PnPDeviceStatus.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Test-PnPDeviceStatus.ps1
```

### Purpose
Reports every matching PnP device sitting in an error state. Strictly read-only.

### Logic
1. Query `Get-PnpDevice -PresentOnly -Status ERROR`
2. Apply the class and device ID wildcard filters from configuration
3. Non-compliant when at least one matching device reports an error state

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Test-PnPDeviceStatus.ps1
```

### Purpose
Removes each matching error-state device and asks Windows to re-detect hardware, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `pnputil.exe` resolves before touching any device
2. Fix: per device, run `pnputil.exe /remove-device <InstanceId>` then `pnputil.exe /scan-devices`, tracking failures per target
3. Post-verify: re-run the detector query — compliant only when no matching error-state devices remain

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
* `<SystemDrive>\IntuneLogs\Test-PnPDeviceStatus\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Test-PnPDeviceStatus.ps1
```

### Remediation Script
```powershell
remediate-Test-PnPDeviceStatus.ps1
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
2. Detection exits with code `1` when matching devices report errors
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation removes each device, rescans hardware, verifies, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — clean devices exit `0` without changes.
* Scope the filters (`$ClassFilterInclude/Exclude`, `$DeviceIDFilterInclude/Exclude`) when you only want specific device classes touched.
* Devices whose drivers reinstall with the same fault will re-trigger the next cycle — that is expected behavior, not a loop defect.
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
