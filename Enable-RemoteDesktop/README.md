<div align="center">

# 🛡️ Enable Remote Desktop

**Intune Proactive Remediation package that enables and hardens Remote Desktop across managed devices.**

Detection verifies the RDP registry values, Network Level Authentication, and the inbound `RDP (TCP)` / `RDP (UDP)` firewall rules, while remediation enforces the full expected configuration — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Enable Remote Desktop** is an Intune remediation package that turns on Remote Desktop with a consistent, hardened configuration across managed devices.

Remote Desktop access is only supportable at fleet scale when it is configured uniformly: `fDenyTSConnections = 0` to allow connections, `fClientDisableUDP = 0` to keep UDP transport available, `UserAuthentication = 1` to enforce Network Level Authentication, and enabled inbound firewall rules for TCP/UDP port 3389. The detection script reads all five conditions read-only; when any condition is unmet, Intune runs the paired remediation that applies the missing settings and verifies the result.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads three registry values (`fDenyTSConnections`, `fClientDisableUDP`, `UserAuthentication`) and both RDP firewall rules
* Never modifies the system during detection
* Reports every unmet condition before triggering remediation

### 🔹 Verified Remediation
* Sets the three registry values (DWORD), updates or creates both inbound firewall rules with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Enable-RemoteDesktop\`

---

# 📂 Project Structure

```text
Enable-RemoteDesktop
│
├── detect-Enable-RemoteDesktop.ps1
├── remediate-Enable-RemoteDesktop.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Enable-RemoteDesktop.ps1
```

### Purpose
Verifies that Remote Desktop and its supporting configuration are present. Strictly read-only.

### Logic
1. Read `fDenyTSConnections` (expected `0`), `fClientDisableUDP` (expected `0`), and `UserAuthentication` (expected `1`)
2. Confirm the inbound `RDP (TCP)` and `RDP (UDP)` firewall rules exist and are enabled
3. Non-compliant when any value is missing/wrong or a rule is missing/disabled; unexpected read failures exit `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Enable-RemoteDesktop.ps1
```

### Purpose
Enables Remote Desktop, NLA, and RDP UDP support, then ensures both inbound port 3389 firewall rules exist, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the base Terminal Server registry key exists
2. Fix: create each registry key/value as needed, update or create both firewall rules for remote address scope `Any`
3. Post-verify: re-read every registry value and firewall rule against the desired state

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
* `<SystemDrive>\IntuneLogs\Enable-RemoteDesktop\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Enable-RemoteDesktop.ps1
```

### Remediation Script
```powershell
remediate-Enable-RemoteDesktop.ps1
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
2. Detection exits with code `1` when any RDP setting or firewall rule is not configured
3. Intune runs the **Remediation Script**
4. Remediation applies the missing settings, verifies them, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* **Exposure warning:** enabling RDP opens inbound TCP/UDP port 3389. Restrict the `$RemoteAddress` scope in the script configuration instead of `Any` where your network design allows it.
* Network Level Authentication (`UserAuthentication = 1`) stays enforced to reduce pre-authentication attack surface.
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
