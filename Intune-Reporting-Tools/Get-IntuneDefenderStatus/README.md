<div align="center">

# 📊 Get Intune Defender Status

**Report Microsoft Defender health status across all Intune managed Windows devices.**

This script pulls Windows protection state from managed devices and reports signature age, real-time protection, scan dates, active threats, and outdated signatures.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Defender Status** is a PowerShell reporting script that Pulls Windows protection state from all managed devices and reports signature age, real-time protection status, last scan dates, devices with active threats, devices with outdated signatures, and devices where Defender is disabled or unhealthy. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Reports per-device windowsProtectionState and detected malware
* Flags RTP disabled, outdated signatures, and active threats
* Calculates signature age and health rate
* Lists unhealthy devices and top signature versions
* Exports CSV for Defender health tracking

---

# 📂 Project Structure

```text
Get-IntuneDefenderStatus
│
├── Get-IntuneDefenderStatus.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneDefenderStatus.ps1
```

*Reports Defender health for all Windows devices*

### Example 2
```powershell
.\Get-IntuneDefenderStatus.ps1 -SignatureAgeDays 7
```
Flags devices with signatures older than 7 days

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `SignatureAgeDays` | int | No | 3 | Flag devices with signatures older than this many days. |
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
* `DeviceManagementManagedDevices.Read.All`

### Logging
* `C:\ProgramData\get-intune-defender-status\Logs`

---

# 🛡 Operational Notes
* Protection state is fetched per device (one request each); large tenants take a few minutes.
* Devices with no protection state are reported as No Data — check enrollment and Defender prerequisites.
* Test in a staging tenant first; Graph permission errors surface as 403 — check Entra consent for the listed scopes.

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