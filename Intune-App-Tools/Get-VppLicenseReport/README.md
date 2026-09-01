<div align="center">

# 🧩 Get VPP License Report

**Reports Apple VPP app license utilization and flags apps and tokens that are close to exhaustion or expiry.**

Reads all Apple Volume Purchase Program tokens and VPP apps from Intune and surfaces used versus total licenses per app plus token health, so administrators can purchase licenses before installs fail and renew expiring tokens.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get-VppLicenseReport** is a PowerShell script that reports Apple Volume Purchase Program license utilization from Microsoft Intune.

It pages VPP tokens and both iOS and macOS VPP apps via Microsoft Graph beta, computes per-app utilization (used over total), classifies each app as OK, NearLimit, Exhausted, or NoLicenses against a configurable warning threshold, and evaluates each VPP token's state and days until expiration. Results are printed grouped by status with token warnings and can be exported as a timestamped CSV. Supports workstation dual-mode authentication: interactive sign-in (WAM-free via MgGraphCommunity) or app-only with tenant, client ID, and secret or certificate.

---

# ✨ Features

* Utilization reporting for iOS and macOS VPP apps with used, total, and percentage
* Configurable warning threshold that flags NearLimit and Exhausted apps
* VPP token state and expiry tracking with warnings for invalid states and near-expiry tokens
* Beta Graph paging for tokens and VPP apps with throttling backoff
* Grouped console output by status and CSV export with full app and utilization data
* Workstation dual-mode Graph authentication
* Structured timestamped logging mirrored to disk

---

# 📂 Project Structure

```text
Get-VppLicenseReport
│
├── Get-VppLicenseReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-VppLicenseReport.ps1
```
Reports all VPP apps with their current license utilization.

### Custom Warning Threshold
```powershell
.\Get-VppLicenseReport.ps1 -WarningThresholdPercent 80
```
Flags apps that have used 80 percent or more of their licenses.

### Export To CSV
```powershell
.\Get-VppLicenseReport.ps1 -ExportToCsv "true"
```
Exports the license report to a timestamped CSV file.

### Custom Output And Expiry Window
```powershell
.\Get-VppLicenseReport.ps1 -TokenExpiryWarningDays 14 -ExportToCsv "true" -OutputPath "C:\Reports"
```
Flags tokens expiring within 14 days and writes the CSV to a specific directory.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| WarningThresholdPercent | Int | No | 90 | Utilization percentage above which an app is flagged (1-100) |
| TokenExpiryWarningDays | Int | No | 30 | Days before token expiry to flag a VPP token (1-365) |
| ExportToCsv | String | No | "false" | Export results to a timestamped CSV file (true/false, 1/0) |
| OutputPath | String | No | "." | Output directory for CSV exports |
| ForceModuleInstall | String | No | "false" | Force Microsoft Graph module installation without prompting (true/false, 1/0) |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Microsoft Graph: `DeviceManagementApps.Read.All`
* Entra role: **Intune Administrator**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed when missing; prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` (auto-installed when available for WAM-free interactive sign-in)

### Logging
* `C:\ProgramData\get-vpp-license-report\Logs\`

---

# 🛡 Operational Notes

* Read-only reporting — creates no tenant objects and purchases no licenses.
* Tenants without Apple VPP (Apps and Books) configured will report zero tokens and zero VPP apps, which is expected.
* License counts come from `iosVppApp` and `macOsVppApp` usedLicenseCount and totalLicenseCount properties.
* Uses beta Graph endpoints because VPP license properties are exposed there; honors HTTP 429 with a 60-second pause.
* An expired VPP token silently breaks app installs — treat token warnings as high priority and renew in Apple Business Manager.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

Migrated to Enterprise Admin standards by **Mohammad Abdelkader Omar**  
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
