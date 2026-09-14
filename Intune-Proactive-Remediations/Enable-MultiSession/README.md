<div align="center">

# 🖥️ Enable Multi-Session

**Intune Proactive Remediation package that removes single-session restrictions so Windows devices allow concurrent user sessions.**

Detection reads `fSingleSessionPerUser` and the optional acNam `EnforceSingleLogon` flag read-only; remediation sets both to `0` and verifies the result — built for shared, lab, and domain-joined fleets.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#️-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#️-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Enable Multi-Session** is an Intune remediation package that lifts the Windows single-session restriction on shared endpoints.

The detection script checks two registry locations read-only: the built-in Terminal Server `fSingleSessionPerUser` flag and the optional third-party acNam credential provider `EnforceSingleLogon` flag. When either is set to `1`, Intune runs the paired remediation, which sets the values to `0` (creating the Terminal Server value when missing, touching the acNam value only when the provider exists) and verifies the result with structured JSON output.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `fSingleSessionPerUser` from the Terminal Server key and `EnforceSingleLogon` from the acNam provider key
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Pre-check → per-target fix → post-verify flow with structured JSON result output for Intune diagnostics
* Creates the Terminal Server value when missing; skips the acNam provider cleanly when it is not installed
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Enable-MultiSession\`

---

# 📂 Project Structure

```text
Enable-MultiSession
│
├── detect-Enable-MultiSession.ps1
├── remediate-Enable-MultiSession.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Enable-MultiSession.ps1
```

### Purpose
Verifies that no single-session restriction is active. Strictly read-only.

### Logic
1. Read `fSingleSessionPerUser` via `Get-ItemProperty` — compliant when `0` or absent
2. Read `EnforceSingleLogon` only when the acNam provider path exists — compliant when `0` or absent
3. Non-compliant when either value is `1`; missing Terminal Server path is reported; unexpected query failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Enable-MultiSession.ps1
```

### Purpose
Sets `fSingleSessionPerUser` and (when present) `EnforceSingleLogon` to `0`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the Terminal Server registry path exists before any mutation
2. Fix: `New-ItemProperty -PropertyType DWord -Value 0 -Force` per target with per-target failure tracking
3. Post-verify: re-read both values and confirm neither is `1`

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
* `<SystemDrive>\IntuneLogs\Enable-MultiSession\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Enable-MultiSession.ps1
```

### Remediation Script
```powershell
remediate-Enable-MultiSession.ps1
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
2. Detection exits with code `1` when a single-session restriction is found
3. Intune runs the **Remediation Script**
4. Remediation sets the restriction flags to `0`, verifies them, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* **Edition limit:** not all Windows editions fully support concurrent interactive sessions; validate on the target SKU.
* **Security impact:** enabling multi-session may conflict with security baselines and third-party credential providers on shared devices.
* A sign-out, restart, or policy refresh may be required before the change is fully effective.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.

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
