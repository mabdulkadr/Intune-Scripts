<div align="center">

# 📊 Get Intune Compliance Report

**Generate a detailed Intune device compliance report showing non-compliant devices and failed settings.**

This script queries Microsoft Graph to retrieve managed devices and their compliance policy states, drilling into specific settings that triggered failures.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Compliance Report** is a PowerShell reporting script that Queries Microsoft Graph to retrieve all managed devices (or a filtered subset) and their compliance policy states. For each non-compliant or in-grace-period device, drills into the specific settings that triggered the failure. Exports a flat CSV with one row per non-compliant setting per device. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Scopes to all devices, single device, or Entra group
* Drills into per-device per-policy settingStates for root cause
* Calculates compliance rate and classifies grace period
* Summarizes top failing policies and settings
* Exports flat CSV with one row per non-compliant setting

---

# 📂 Project Structure

```text
Get-IntuneComplianceReport
│
├── Get-IntuneComplianceReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneComplianceReport.ps1
```

*Reports all non-compliant devices across the tenant*

### Example 2
```powershell
.\Get-IntuneComplianceReport.ps1 -DeviceName "L-PF4Z0HM0"
```
Deep-dive compliance for a single device

### Example 3
```powershell
.\Get-IntuneComplianceReport.ps1 -GroupName "SG-Intune-Windows-Devices" -ExportPath "C:\temp\compliance.csv"
```
Compliance report for devices in a specific group

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceName` | string | No | - | Report on a single device by name. |
| `GroupName` | string | No | - | Report on devices belonging to a specific Entra ID group. |
| `IncludeCompliant` | switch | No | false | Include compliant devices in the report. |
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
* `DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All`

### Logging
* `C:\ProgramData\get-intune-compliance-report\Logs`

---

# 🛡 Operational Notes
* Compliance evaluation is tenant-specific; verify tenant setting “Mark devices with no compliance policy assigned as” — uncovered platforms may silently pass.
* GroupName resolution supports device groups and user groups; user groups enumerate member devices.
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