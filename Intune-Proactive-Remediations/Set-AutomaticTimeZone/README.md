<div align="center">

# 🪟 Set Automatic Time Zone

**Intune Proactive Remediation package that enables Windows automatic time zone updates.**

Detection reads the location consent and `tzautoupdate` service registry values and remediation enforces the expected settings so managed devices keep their clock in the correct time zone automatically.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Set Automatic Time Zone** is an Intune remediation package that turns on automatic time zone detection across managed devices.

Windows can only update the time zone on its own when two conditions hold: location access is allowed in the Capability Access Manager consent store, and the `tzautoupdate` service is set to start on demand (`Start = 3`). The detection script reads both values read-only; when either one is missing or wrong, Intune runs the paired remediation that writes them and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `Value` from `HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore\location`
* Reads `Start` from `HKLM:\SYSTEM\CurrentControlSet\Services\tzautoupdate`
* Never modifies the system during detection and reports every unmet condition

### 🔹 Verified Remediation
* Writes location consent = `Allow` (String) and `tzautoupdate Start = 3` (DWORD) with a pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Set-AutomaticTimeZone\`

---

# 📂 Project Structure

```text
Set-AutomaticTimeZone
│
├── detect-Set-AutomaticTimeZone.ps1
├── remediate-Set-AutomaticTimeZone.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Set-AutomaticTimeZone.ps1
```

### Purpose
Verifies that both automatic time zone prerequisites are configured. Strictly read-only.

### Logic
1. Read the location consent value — must equal `Allow`
2. Read the `tzautoupdate` service `Start` value — must equal `3`
3. Non-compliant when either value is missing or set to anything else

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Set-AutomaticTimeZone.ps1
```

### Purpose
Enables automatic time zone updates by writing both registry values, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm both parent registry keys exist
2. Fix: `New-ItemProperty -Force` writes `Allow` (String) and `Start = 3` (DWord)
3. Post-verify: read both values back and compare against the desired state

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
* `<SystemDrive>\IntuneLogs\Set-AutomaticTimeZone\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Set-AutomaticTimeZone.ps1
```

### Remediation Script
```powershell
remediate-Set-AutomaticTimeZone.ps1
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
2. Detection exits with code `1` when either registry value is wrong or missing
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation writes the values, verifies them, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* Location consent is a device-wide HKLM setting; per-app consent entries are not touched.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.
* Time zone changes take effect after the next location refresh; no reboot is forced.

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
