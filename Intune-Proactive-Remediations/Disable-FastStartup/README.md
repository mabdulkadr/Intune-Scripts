<div align="center">

# 🛡️ Disable Fast Startup

**Intune Proactive Remediation package that keeps Windows Fast Startup (Hiberboot) disabled.**

Detection verifies the `HiberbootEnabled` registry value and remediation enforces `0` so every managed device performs a full startup — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Disable Fast Startup** is an Intune remediation package that disables Windows Fast Startup (Hiberboot) across managed devices.

Fast Startup saves kernel and session state to disk on shutdown, which can produce stale device state, blocked driver updates, and confusing restart behavior on managed fleets. Enterprise baselines therefore require `HiberbootEnabled = 0`. The detection script reads the value read-only; when it is missing or non-zero, Intune runs the paired remediation that sets it and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `HiberbootEnabled` from `HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power`
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Sets `HiberbootEnabled` to `0` (DWORD) with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Disable-FastStartup\`

---

# 📂 Project Structure

```text
Disable-FastStartup
│
├── detect-Disable-FastStartup.ps1
├── remediate-Disable-FastStartup.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Disable-FastStartup.ps1
```

### Purpose
Verifies that Fast Startup is disabled. Strictly read-only.

### Logic
1. Read `HiberbootEnabled` from the Session Manager `Power` registry key
2. Compliant when the value equals `0`
3. Non-compliant when the value is missing or set to anything else

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Disable-FastStartup.ps1
```

### Purpose
Disables Fast Startup by setting `HiberbootEnabled` to `0`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the parent registry key exists
2. Fix: `Set-ItemProperty` writes `HiberbootEnabled = 0` (DWORD)
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
* `<SystemDrive>\IntuneLogs\Disable-FastStartup\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Disable-FastStartup.ps1
```

### Remediation Script
```powershell
remediate-Disable-FastStartup.ps1
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
2. Detection exits with code `1` when Fast Startup is enabled
3. Intune runs the **Remediation Script**
4. Remediation sets the value, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* Takes effect on the next full shutdown/startup cycle; no reboot is forced.
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
