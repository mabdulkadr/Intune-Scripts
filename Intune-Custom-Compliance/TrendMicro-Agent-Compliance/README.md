<div align="center">

# 🛡️ Trend Micro Apex One - App Presence Compliance

**Intune Custom Compliance discovery script that reports whether the Trend Micro Apex One Security Agent is installed.**

Checks four independent signals (registry ARP entries, services, program folders, and processes) and emits a single JSON property (`true`/`false`) that the Intune custom compliance policy evaluates against its rules.

[![Intune](https://img.shields.io/badge/Intune-Custom%20Compliance-10B981?style=for-the-badge)](#-intune-custom-compliance-setup)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Usage](#-usage) • [Requirements](#-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Trend Micro Apex One - App Presence Compliance** is a Microsoft Intune custom compliance discovery script.

It checks for the presence of the Trend Micro agent executable using two independent signals:

1. **Folder markers** — The program folder exists and contains a known marker executable (`PccNt.exe` / `PccNTMon.exe`).
2. **Processes** — Any of the Trend Micro agent processes active in memory (`ntrtscan`, `PccNTMon`, `TmListen`).

Any single positive signal marks the agent as installed. The script emits a compact JSON property bag that Intune's custom compliance engine evaluates against the rule file.

---

# ✨ Features

### 🔹 Multi-Signal Executable Detection
* Robust across varied install layouts — folder-marker and process signals
* Any one positive signal marks the agent as installed

### 🔹 Optimized for Intune
* SysWOW64 (IME) PowerShell 5.1 compatible
* No slow `Win32_Product` / WMI enumeration — only fast metadata reads
* Runs to completion in seconds, well under the compliance script timeout

### 🔹 Enterprise Standards
* Structured logging, typed error handling — read-only executable-presence checks
* Read-only: never modifies the filesystem, registry, services, or processes
* Errors exit `2` so Intune never evaluates a crashed discovery as valid output

---

# 📂 Project Structure

```text
TrendMicro-Agent-Compliance
│
├── Get-TrendMicroAgentCompliance.ps1
├── TrendMicro-Agent-Compliance.json
└── README.md
```

---

# 🚀 Usage

```powershell
.\Get-TrendMicroAgentCompliance.ps1
```

Emits the JSON property bag Intune evaluates against the imported rule file:

```json
{"Trend Micro Apex One Security Agent":true}
```

When the agent is absent:

```json
{"Trend Micro Apex One Security Agent":false}
```

The companion `TrendMicro-Agent-Compliance.json` defines the validation rules Intune applies to that property: expected value, operator, more-info URL, and the non-compliance message.

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `C:\IntuneLogs\TrendMicroAgentCompliance\TrendMicroAgentCompliance-Compliance.txt`

---

## ☁️ Intune Custom Compliance Setup

1. Import `TrendMicro-Agent-Compliance.json` as the custom compliance **validation rule file**
2. Upload `Get-TrendMicroAgentCompliance.ps1` as the **discovery script**
3. Assign the resulting policy to your device groups

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🛡 Operational Notes
* The rule file `SettingName` (`Trend Micro Apex One Security Agent`) and the JSON key emitted by the script must match 1:1 — renaming one requires updating the other.
* Detection signals are markers only and are tuned to avoid false positives from unrelated Trend products.
* The script is read-only: it discovers, it never remediates. Use a separate remediation plan or app deployment to install the agent when `false` is reported.

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
