<div align="center">

# 🛡️ Ensure System Restore Point Monthly

**Intune Proactive Remediation package that guarantees a fresh system restore point every month.**

Detection checks both restore-point providers for an accepted current-month checkpoint, and remediation enables System Protection if needed and creates the missing monthly restore point — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Ensure System Restore Point Monthly** is an Intune remediation package that keeps at least one valid system restore point available per month on managed devices.

Recovery options are only useful when they exist before the incident. The detection script enumerates restore points from `Get-ComputerRestorePoint` and the `root/default` `SystemRestore` WMI provider (deduplicated), and treats the device as compliant when a point matches an accepted prefix (`Monthly System Restore Point`, `Intune Monthly Restore Point`, `System Safety Restore Point`) within the current month, or any description tagged with the current `(yyyy-MM)` month tag. When no valid point exists, Intune runs the paired remediation that enables System Protection on the OS drive if needed, temporarily clears the 24-hour creation throttle, creates a `MODIFY_SETTINGS` checkpoint (falling back to `APPLICATION_INSTALL`), restores the throttle value, and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries both restore-point providers and deduplicates the combined result
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Enables System Protection when unavailable, clears the throttle temporarily, and creates the monthly checkpoint with pre-check → fix → post-verify flow
* Restores or removes the `SystemRestorePointCreationFrequency` registry value after creation
* Emits structured JSON result output for Intune diagnostics
* Idempotent — skips creation when a valid monthly point already exists

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Ensure-SystemRestorePointMonthly\`

---

# 📂 Project Structure

```text
Ensure-SystemRestorePointMonthly
│
├── detect-Ensure-SystemRestorePointMonthly.ps1
├── remediate-Ensure-SystemRestorePointMonthly.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Ensure-SystemRestorePointMonthly.ps1
```

### Purpose
Verifies that a valid restore point exists for the current month. Strictly read-only.

### Logic
1. Collect restore points from `Get-ComputerRestorePoint` and WMI `SystemRestore`, deduplicate
2. Compliant when one matches an accepted prefix in-month or carries the current `(yyyy-MM)` tag
3. Non-compliant otherwise; unexpected enumeration failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Ensure-SystemRestorePointMonthly.ps1
```

### Purpose
Ensures a valid monthly restore point exists by enabling System Protection if needed and creating the checkpoint, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: resolve the OS drive letter from `Win32_OperatingSystem`
2. Fix: skip when already compliant; otherwise enable System Protection and run `Checkpoint-Computer` with the throttle temporarily cleared (`MODIFY_SETTINGS`, fallback `APPLICATION_INSTALL`)
3. Post-verify: re-enumerate restore points and confirm a valid monthly point now exists

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
* `<SystemDrive>\IntuneLogs\Ensure-SystemRestorePointMonthly\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Ensure-SystemRestorePointMonthly.ps1
```

### Remediation Script
```powershell
remediate-Ensure-SystemRestorePointMonthly.ps1
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
2. Detection exits with code `1` when no accepted restore point exists for the current month
3. Intune runs the **Remediation Script**
4. Remediation creates the checkpoint, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices with a valid current-month point exit `0` without changes.
* The 24-hour restore-point throttle is bypassed only during creation and restored afterwards; the original `SystemRestorePointCreationFrequency` value is preserved.
* **Storage impact:** each checkpoint consumes disk space under System Protection; monitor shadow-storage limits on small drives.
* Creating restore points can take several minutes on low-spec devices — keep the Intune script timeout generous.
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
