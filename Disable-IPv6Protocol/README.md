<div align="center">

# 🌐 Disable IPv6 Protocol

**Intune Proactive Remediation package that disables the IPv6 binding on every network adapter and sets the system-wide IPv6 registry policy.**

Detection verifies the `ms_tcpip6` binding state on all adapters and remediation disables remaining bindings and writes `DisabledComponents = 255` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Disable IPv6 Protocol** is an Intune remediation package that enforces IPv6-disabled baselines across managed devices.

The detection script queries `Get-NetAdapterBinding -ComponentID ms_tcpip6` and reports non-compliant when any adapter still has the binding enabled or when no bindings are returned. The paired remediation then runs `Disable-NetAdapterBinding` per adapter and writes `HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters\DisabledComponents` as a DWORD `255`, verifying the value afterwards. Microsoft recommends preferring disabled components over unbinding adapters alone; a restart is required before all changes fully take effect.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries the `ms_tcpip6` binding on every network adapter without modifying anything
* Reports every enabled adapter before triggering remediation
* Detection errors exit `2` so Intune never treats a crash as non-compliance

### 🔹 Verified Remediation
* Disables each remaining binding with `Disable-NetAdapterBinding -Confirm:$false` and tracks per-adapter failures
* Writes `DisabledComponents = 255` (DWORD) with `New-ItemProperty -Force`, then reads the value back
* Pre-check → fix → post-verify flow with structured JSON result output

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Disable-IPv6Protocol\`

---

# 📂 Project Structure

```text
Disable-IPv6Protocol
│
├── detect-Disable-IPv6Protocol.ps1
├── remediate-Disable-IPv6Protocol.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Disable-IPv6Protocol.ps1
```

### Purpose
Verifies that the IPv6 binding is disabled on all detected adapters. Strictly read-only.

### Logic
1. Query `Get-NetAdapterBinding -ComponentID ms_tcpip6`
2. Compliant only when bindings exist and none are enabled
3. Non-compliant when one or more adapters still have IPv6 enabled, or when no bindings are returned

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Disable-IPv6Protocol.ps1
```

### Purpose
Disables remaining IPv6 bindings and writes the system-wide registry setting, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the Tcpip6 `Parameters` registry key exists and capture current bindings
2. Fix: `Disable-NetAdapterBinding -Name <adapter> -ComponentID ms_tcpip6 -Confirm:$false` per enabled adapter, then `New-ItemProperty ... DisabledComponents = 255` (DWORD, Force)
3. Post-verify: read `DisabledComponents` back and fail the run when it differs from `255` or when any adapter disable failed

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
* `<SystemDrive>\IntuneLogs\Disable-IPv6Protocol\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Disable-IPv6Protocol.ps1
```

### Remediation Script
```powershell
remediate-Disable-IPv6Protocol.ps1
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
2. Detection exits with code `1` when IPv6 is still enabled on one or more adapters
3. Intune runs the **Remediation Script**
4. Remediation disables the bindings, writes the registry policy, verifies, and logs results

---

# 🛡 Operational Notes
* A **restart is required** before the full system-level effect of `DisabledComponents = 255`.
* Disabling IPv6 entirely can break features that rely on it (DirectAccess, some homegrown tooling, DHCPv6 environments) — validate your network baseline first.
* Idempotent: already-disabled bindings are skipped and the registry write is force-overwritten.
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
