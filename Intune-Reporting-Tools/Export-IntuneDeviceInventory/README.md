<div align="center">

# 📊 Export-IntuneDeviceInventory

**Exports a comprehensive Intune device inventory with hardware, OS, compliance, and enrollment details.**

Queries Microsoft Graph to build a complete device inventory combining Intune managed devices and Entra ID records with hardware, OS, compliance, encryption, storage, primary user, and enrollment details for asset management and lifecycle planning.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Export-IntuneDeviceInventory** is a PowerShell reporting script that queries Microsoft Graph to build a complete device inventory combining Intune managed devices and Entra ID records with hardware, OS, compliance, encryption, storage, primary user, and enrollment details for asset management and lifecycle planning.

It combines Intune managed devices with Entra ID device records to enrich sync and trust data, supports OS and group filtering, and optionally counts detected apps per device. The inventory is ideal for asset management, auditing, and lifecycle planning.

---

# ✨ Features

* Combines Intune managed devices with Entra ID records for enrichment
* Includes hardware, OS, compliance, encryption, storage, and enrollment fields
* Supports OS filtering, Entra ID group scoping, and detected app counts
* Calculates days since sync, device age, and storage utilization
* Exports CSV beside the script with `Get-MgGraphAllPages` pagination

---

# 📂 Project Structure

```text
Export-IntuneDeviceInventory
│
├── Export-IntuneDeviceInventory.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Export-IntuneDeviceInventory.ps1
```

### Example 1
```powershell
.\Export-IntuneDeviceInventory.ps1
```
Exports inventory for all managed devices.

### Example 2
```powershell
.\Export-IntuneDeviceInventory.ps1 -OSFilter "Windows" -ExportPath "C:\temp\windows_inventory.csv"
```
Exports Windows devices only to a specific CSV.

### Example 3
```powershell
.\Export-IntuneDeviceInventory.ps1 -GroupName "SG-Intune-Pilot" -IncludeDetectedApps
```
Exports devices in a group with detected app counts.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `OSFilter` | String | No | - | Filter by operating system (e.g., Windows, iOS, Android, macOS). |
| `GroupName` | String | No | - | Scope to devices in a specific Entra ID group. |
| `IncludeDetectedApps` | Switch | No | False | Add a count of detected apps per device (slower). |
| `ExportPath` | String | No | Beside script | Optional export path for the CSV. |

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
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementManagedDevices.Read.All, Device.Read.All, Directory.Read.All, Group.Read.All, GroupMember.Read.All, User.Read.All, DeviceManagementApps.Read.All`

### Logging
* `C:\ProgramData\Export-IntuneDeviceInventory\Logs\`

---

# 🛡 Operational Notes
* Read-only; never modifies devices or groups.
* Detected apps mode issues one Graph call per device — slower on large tenants.
* Verify group names exactly; missing groups exit gracefully with an ERROR log.

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