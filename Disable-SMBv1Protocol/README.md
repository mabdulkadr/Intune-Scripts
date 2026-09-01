<div align="center">

# 🔒 Disable SMBv1 Protocol

**Intune Proactive Remediation package that removes the legacy SMBv1 server protocol from Windows devices.**

Detection verifies `EnableSMB1Protocol` in the SMB server configuration and remediation turns it off so managed devices stop exposing an outdated, wormable-exploit-friendly protocol — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Disable SMBv1 Protocol** is an Intune remediation package that disables SMBv1 across managed devices.

SMBv1 is a decades-old protocol with no modern security protections; it is the entry vector for wormable attacks such as EternalBlue/WannaCry and should not be present on enterprise networks. Enterprise baselines therefore require `EnableSMB1Protocol = $false`. The detection script reads the SMB server configuration read-only via `Get-SmbServerConfiguration`; when SMBv1 is enabled, Intune runs the paired remediation that sets it to `0` and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `EnableSMB1Protocol` from the SMB server configuration (`Get-SmbServerConfiguration`)
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Runs `Set-SmbServerConfiguration -EnableSMB1Protocol 0` with a pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Disable-SMBv1Protocol\`

---

# 📂 Project Structure

```text
Disable-SMBv1Protocol
│
├── detect-Disable-SMBv1Protocol.ps1
├── remediate-Disable-SMBv1Protocol.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Disable-SMBv1Protocol.ps1
```

### Purpose
Verifies that the SMBv1 server protocol is disabled. Strictly read-only.

### Logic
1. Read the SMB server configuration via `Get-SmbServerConfiguration`
2. Compliant when `EnableSMB1Protocol` is `$false`
3. Non-compliant when SMBv1 is still enabled; unexpected query failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Disable-SMBv1Protocol.ps1
```

### Purpose
Disables SMBv1 by setting `EnableSMB1Protocol` to `0`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the SMB server configuration can be queried
2. Fix: `Set-SmbServerConfiguration -EnableSMB1Protocol 0 -Force -Confirm:$false`
3. Post-verify: re-query the configuration and confirm SMBv1 is disabled

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
* `<SystemDrive>\IntuneLogs\Disable-SMBv1Protocol\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Disable-SMBv1Protocol.ps1
```

### Remediation Script
```powershell
remediate-Disable-SMBv1Protocol.ps1
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
2. Detection exits with code `1` when SMBv1 is enabled
3. Intune runs the **Remediation Script**
4. Remediation disables SMBv1, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* **Security impact:** disabling SMBv1 breaks access to legacy file shares, older NAS devices, and pre-Windows Vista/Server 2008 clients that still depend on it.
* Inventory legacy dependencies on pilot devices before broad deployment.
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
