<div align="center">

# 📊 Get Intune App Status Report

**Generate a detailed Intune app installation status report with deployment results per app per device.**

This script queries Microsoft Graph to retrieve app installation status across managed devices, showing succeeded, failed, or pending installations with error codes and install state details.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune App Status Report** is a PowerShell reporting script that Queries Microsoft Graph to retrieve app installation status across managed devices. Shows which apps succeeded, failed, or are pending installation, including error codes, failure reasons, and install state details. Supports filtering by a single app, a single device, or all assigned apps. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Reports per-app per-device install states with error codes
* Filters by AppName or DeviceName scope
* Highlights top failing apps and error codes
* Supports -IncludeAll for full state inventory
* Auto-exports CSV with timestamped filename

---

# 📂 Project Structure

```text
Get-IntuneAppStatusReport
│
├── Get-IntuneAppStatusReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneAppStatusReport.ps1
```

*All assigned apps - failed installations only*

### Example 2
```powershell
.\Get-IntuneAppStatusReport.ps1 -AppName "Microsoft Teams"
```
Status for a specific app across all devices

### Example 3
```powershell
.\Get-IntuneAppStatusReport.ps1 -DeviceName "L-PF4Z0HM0" -IncludeAll
```
All app statuses for a single device

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `AppName` | string | No | - | Filter by app display name (supports partial match). |
| `DeviceName` | string | No | - | Report app status for a single device. |
| `IncludeAll` | switch | No | false | Include all installation states (default is failed only). |
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
* `DeviceManagementApps.Read.All,DeviceManagementManagedDevices.Read.All,Device.Read.All,Directory.Read.All`

### Logging
* `C:\ProgramData\get-intune-app-status-report\Logs`

---

# 🛡 Operational Notes
* App install states are reported per assigned app; unassigned apps do not appear in results.
* Large tenants with many apps may take several minutes; per-app deviceStatus calls are throttled with short delays.
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