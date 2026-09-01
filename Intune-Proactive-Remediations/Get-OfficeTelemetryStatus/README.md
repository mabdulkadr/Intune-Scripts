<div align="center">

# 🛡️ Get Office Telemetry Status

**Intune Proactive Remediation package that keeps Office client telemetry disabled for device users.**

Detection verifies the `DisableTelemetry` policy value under `HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry` and remediation enforces `1` — reducing diagnostic data sent to Microsoft from managed endpoints.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Office Telemetry Status** is an Intune remediation package that keeps Microsoft Office client telemetry disabled across managed devices.

Office apps can send diagnostic and usage telemetry to Microsoft. Enterprise privacy baselines therefore enforce the `DisableTelemetry` policy value per user. The detection script reads `HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry\DisableTelemetry` read-only; when it is missing or not `1`, Intune runs the paired remediation that creates the policy key, writes the DWORD value, and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `DisableTelemetry` from `HKCU:\Software\Policies\Microsoft\office\common\clienttelemetry`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Creates the policy key if absent and writes `DisableTelemetry = 1` (DWORD) with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Get-OfficeTelemetryStatus\`

---

# 📂 Project Structure

```text
Get-OfficeTelemetryStatus
│
├── detect-Get-OfficeTelemetryStatus.ps1
├── remediate-Get-OfficeTelemetryStatus.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Get-OfficeTelemetryStatus.ps1
```

### Purpose
Verifies that Office client telemetry is disabled for the current user. Strictly read-only.

### Logic
1. Read `DisableTelemetry` from the Office clienttelemetry policy key
2. Compliant when the value equals `1`
3. Non-compliant when the value is missing or set to anything else; unexpected read failures exit with code `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Get-OfficeTelemetryStatus.ps1
```

### Purpose
Creates the Office policy key when needed and writes `DisableTelemetry = 1`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the `HKCU:\Software\Policies\Microsoft` hive path is reachable
2. Fix: create `...\office\common\clienttelemetry` if absent, then write `DisableTelemetry = 1` (DWord)
3. Post-verify: read the value back and compare against the desired state

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
* `<SystemDrive>\IntuneLogs\Get-OfficeTelemetryStatus\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Get-OfficeTelemetryStatus.ps1
```

### Remediation Script
```powershell
remediate-Get-OfficeTelemetryStatus.ps1
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
2. Detection exits with code `1` when the telemetry policy is missing or disabled incorrectly
3. Intune runs the **Remediation Script**
4. Remediation writes the policy value, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* The pair targets HKCU. When run in SYSTEM context the policy applies to profiles as loaded at runtime; assign in user context if you need per-user coverage on shared devices.
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
