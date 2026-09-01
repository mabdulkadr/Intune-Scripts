<div align="center">

# 🧩 Get Application Inventory

**Generates a comprehensive application inventory report for all managed devices in Intune.**

Scans every managed device and its detected applications, enriching publisher, platform, and size from the aggregate detectedApps endpoint, and produces CSV and HTML inventory reports with summary statistics — built for Intune administrators tracking fleet-wide software posture.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get-ApplicationInventory** is a PowerShell script that builds a fleet-wide application inventory from Microsoft Intune managed devices.

It connects to Microsoft Graph, pages managed devices with a hard cap via `-MaxDevices`, builds a metadata lookup from the aggregate `deviceManagement/detectedApps` endpoint to enrich the per-device expand (which otherwise returns null publishers and zero sizes), and expands each device's `detectedApps` to produce per-device, per-app rows. Results are exported as timestamped CSV and HTML with top applications and publishers. Supports workstation dual-mode authentication: interactive sign-in (WAM-free via MgGraphCommunity when available) or app-only with tenant, client ID, and secret or certificate.

---

# ✨ Features

* Fleet-wide inventory across all managed devices with device, user, OS, and compliance context
* Publisher, platform, and size enrichment from the aggregate detectedApps lookup
* System-app exclusion by default with override via `-IncludeSystemApps`
* Filtering by publisher and application name with wildcard support
* Timestamped CSV and styled HTML exports with top applications and publishers
* Hard-capped device paging and throttling-aware retry with per-device re-attempts
* Structured timestamped logging mirrored to disk

---

# 📂 Project Structure

```text
Get-ApplicationInventory
│
├── Get-ApplicationInventory.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-ApplicationInventory.ps1
```
Generates application inventory reports for all managed devices.

### Include System Apps With Custom Output
```powershell
.\Get-ApplicationInventory.ps1 -OutputPath "C:\Reports" -IncludeSystemApps "true"
```
Generates reports including system applications and saves them to the specified directory.

### Filter By Publisher And Open Report
```powershell
.\Get-ApplicationInventory.ps1 -FilterByPublisher "Microsoft Corporation" -OpenReport "true"
```
Generates reports filtered by Microsoft applications and opens the HTML report automatically.

### Force Module Install
```powershell
.\Get-ApplicationInventory.ps1 -ForceModuleInstall "true"
```
Forces module installation without prompting and generates the report.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| OutputPath | String | No | "." | Output directory for CSV and HTML reports |
| IncludeSystemApps | String | No | "false" | Include Windows system applications (true/false, 1/0) |
| FilterByPublisher | String | No | "" | Filter inventory by publisher name (wildcard) |
| FilterByAppName | String | No | "" | Filter inventory by application name (wildcard) |
| OpenReport | String | No | "false" | Open the generated HTML report automatically (true/false, 1/0) |
| MaxDevices | Int | No | 0 | Maximum number of devices to process (0 = all) |
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
* Microsoft Graph: `DeviceManagementManagedDevices.Read.All`
* Entra role: **Intune Administrator**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed when missing; prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` (auto-installed when available for WAM-free interactive sign-in)

### Logging
* `C:\ProgramData\get-application-inventory-report\Logs\`

---

# 🛡 Operational Notes

* Read-only reporting — creates no tenant objects and installs nothing on devices.
* Large tenants may take considerable time due to API rate limits; the script pauses automatically on HTTP 429 and retries up to three times per device.
* System applications are excluded by default to focus on business applications.
* Uses the beta Graph endpoint for enhanced application data; per-device detectedApps are enriched from the aggregate endpoint.
* Report auto-open failures emit warnings and do not abort the overall run.

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
