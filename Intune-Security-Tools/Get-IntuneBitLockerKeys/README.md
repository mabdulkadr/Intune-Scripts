<div align="center">

# 🔒 Get Intune BitLocker Keys

**Retrieve BitLocker recovery keys from Entra ID for Intune managed devices.**

This script operates in lookup mode for helpdesk key recovery and audit mode to scan all Windows devices for escrowed key coverage and compliance gaps.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune BitLocker Keys** is a PowerShell reporting script that Operates in two modes: 1. LOOKUP - Retrieve BitLocker recovery key(s) for a specific device by name, serial number, or Entra device ID. Designed for helpdesk key recovery. 2. AUDIT - Scan all Windows managed devices and report which ones have recovery keys escrowed to Entra ID and which are missing. Designed for security compliance auditing. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Security Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Lookup recovery keys by DeviceName or SerialNumber
* Audit all Windows devices for escrowed key coverage
* Masks keys by default; -ShowKeys for full display
* Supports group-scoped audits via GroupName
* Flags encrypted devices missing escrowed keys

---

# 📂 Project Structure

```text
Get-IntuneBitLockerKeys
│
├── Get-IntuneBitLockerKeys.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneBitLockerKeys.ps1 -DeviceName "L-PF4Z0HM0" -ShowKeys
```

*Retrieve and display recovery keys for a specific device*

### Example 2
```powershell
.\Get-IntuneBitLockerKeys.ps1 -SerialNumber "PF4Z0HM0"
```
Look up by serial number

### Example 3
```powershell
.\Get-IntuneBitLockerKeys.ps1 -Audit -ExportPath "C:\temp\bitlocker_audit.csv"
```
Audit all Windows devices for escrowed keys

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceName` | string | Yes (ByName) | - | Look up recovery keys for a device by Intune device name. |
| `SerialNumber` | string | Yes (BySerial) | - | Look up recovery keys for a device by serial number. |
| `Audit` | switch | Yes (Audit) | false | Run in audit mode - check all Windows devices for escrowed keys. |
| `GroupName` | string | No | - | Scope the audit to devices in a specific Entra ID group. |
| `ShowKeys` | switch | No | false | Display the actual recovery key values in console output. |
| `ExportPath` | string | No | - | Optional. Export results to CSV at the specified path. |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success |
| 1 | Failure |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Permissions
* `DeviceManagementManagedDevices.Read.All,BitlockerKey.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All`

### Logging
* `C:\ProgramData\get-intune-bitlocker-keys\Logs`

---

# 🛡 Operational Notes
* Key retrieval is audited in Entra ID; BitlockerKey.Read.All grants sensitive access — restrict to helpdesk admins.
* Encrypted devices with KEY MISSING are unrecoverable if TPM/OS fails — prioritize remediation.
* CSV exports contain full recovery keys; store securely and encrypt at rest.

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