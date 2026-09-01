<div align="center">

# 🛡️ App Version Compliance

**Intune Custom Compliance discovery script that reports installed versions for configured applications.**

Reads the Windows uninstall registry views and emits one JSON property per application (`true`/`false`), which the Intune custom compliance policy evaluates against its rules.

[![Intune](https://img.shields.io/badge/Intune-Custom%20Compliance-10B981?style=for-the-badge)](#%EF%B8%8F-requirements)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**App Version Compliance** is a Microsoft Intune custom compliance discovery script.

The script sweeps the uninstall registry keys (HKLM machine-wide by default, HKCU per-user optionally) for each configured display name and emits a compressed JSON property bag such as `{"Google Chrome":"141.0.7390.66"}`. Intune's custom compliance engine compares those properties against the rules defined in `Get-AppVersionCompliance.json` to decide device compliance.

---

# ✨ Features

### 🔹 Two Discovery Modes
* Install check only — `true` / `false` per application
* Version mode — returns the installed display version, `0.0.0.0` when absent

### 🔹 Flexible Hive Targeting
* `$UserProfileApp = $false` → HKLM (64-bit + WOW6432Node views)
* `$UserProfileApp = $true` → HKCU per-user installs

### 🔹 Enterprise Standards
* Canonical rich header, structured logging, typed error handling
* Errors exit `2` so Intune never evaluates a crashed discovery as valid output

---

# 📂 Project Structure

```text
App Version Compliance
│
├── Get-AppVersionCompliance.ps1
├── Get-AppVersionCompliance.json
└── README.md
```

---

# 🚀 Usage

```powershell
.\Get-AppVersionCompliance.ps1
```

Emits the JSON property bag Intune evaluates against the imported rule file:

```json
{"Google Chrome":"141.0.7390.66"}
```

In version mode (`$IsAppInstallCheckOnly = $false`) the same sweep returns versions:

```json
{"Google Chrome":"141.0.7390.66"}
```

Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Discovery succeeded - JSON emitted |
| 2    | Script error |

The companion `Get-AppVersionCompliance.json` defines the validation rules Intune applies to those properties: expected value, operator, more-info URL, and the non-compliance message.

---

# ⚙️ Parameters

Configuration lives at the top of the script (Intune runs discovery scripts parameterless):

| Variable | Default | Purpose |
| -------- | ------- | ------- |
| `$ApplicationNames` | `@("Google Chrome")` | Exact display names as shown in Programs and Features |
| `$UserProfileApp` | `$false` | `$false` = HKLM machine-wide, `$true` = HKCU per-user |
| `$IsAppInstallCheckOnly` | `$false` | `$false` = version strings (default), `$true` = presence booleans |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `C:\ProgramData\Get-AppVersionCompliance\Logs`

---

## ☁️ Intune Custom Compliance Setup

1. Import `Get-AppVersionCompliance.json` as the custom compliance **validation rule file**
2. Upload `Get-AppVersionCompliance.ps1` as the **discovery script**
3. Assign the resulting policy to your device groups

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🛡 Operational Notes
* Application names are matched case-sensitively and must match Programs and Features exactly.
* Keep the application list short — every entry adds registry-matching work on each sync.
* The JSON property names here must align 1:1 with the rule file; renaming an app requires updating both files.

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
