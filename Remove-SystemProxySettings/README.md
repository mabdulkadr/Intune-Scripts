<div align="center">

# 🌐 Remove System Proxy Settings

**Intune Proactive Remediation package that clears the current user's WinINET proxy configuration.**

Detection reads `ProxyEnable` and `ProxyServer` under the current user's Internet Settings registry key — remediation disables the proxy and clears the server string, then verifies both values match the cleared state.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Remove System Proxy Settings** is an Intune remediation package that removes stale or unwanted WinINET proxy settings from managed users.

The detection script treats a device as non-compliant when `ProxyEnable` equals `1` or a `ProxyServer` string is configured under `HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings`. The paired remediation then sets `ProxyEnable` to `0`, clears `ProxyServer`, and re-reads both values to confirm the cleared state before reporting success.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `ProxyEnable` and `ProxyServer` from the current user's Internet Settings key
* Flags an enabled proxy or any configured server string independently
* Never modifies the system during detection

### 🔹 Verified Remediation
* Pre-check confirms the registry key exists and records the pre-state
* Writes `ProxyEnable = 0` and clears `ProxyServer` with failure tracking
* Re-reads both values to verify the cleared state; emits structured JSON output
* Unexpected errors exit `2` instead of being masked as failures

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Remove-SystemProxySettings\`

---

# 📂 Project Structure

```text
Remove-SystemProxySettings
│
├── detect-Remove-SystemProxySettings.ps1
├── remediate-Remove-SystemProxySettings.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Remove-SystemProxySettings.ps1
```

### Purpose
Checks the current user for a configured WinINET proxy. Strictly read-only.

### Logic
1. Read `ProxyEnable` and `ProxyServer` from the Internet Settings key
2. Non-compliant when ProxyEnable equals `1`
3. Non-compliant when ProxyServer holds a non-empty value

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Remove-SystemProxySettings.ps1
```

### Purpose
Clears the current user's proxy settings, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the Internet Settings key exists and log the pre-state
2. Fix: `Set-ItemProperty` writes `ProxyEnable = 0` and empties `ProxyServer`
3. Post-verify: re-read both values and compare against the cleared definition

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
* Runs via Intune in SYSTEM or user context per assignment — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Remove-SystemProxySettings\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Remove-SystemProxySettings.ps1
```

### Remediation Script
```powershell
remediate-Remove-SystemProxySettings.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

> Assign in the logged-on user context so HKCU points at the real user's hive.

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` a proxy is enabled or configured
3. Intune runs the **Remediation Script**
4. Remediation clears both values, verifies, and logs results

---

# 🛡 Operational Notes
* **Removing proxy settings impacts networks that require an explicit proxy** — devices behind forced-proxy gateways lose connectivity if they depended on these values.
* Registry changes apply to new WinINET sessions; running applications may keep using cached proxy state until restarted.
* The remediation writes values (enable flag off, server emptied) rather than deleting the key, matching the legacy behavior exactly.
* Per-user HKCU scope means each user on a shared device is handled by their own Intune user-context run.
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
