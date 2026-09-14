<div align="center">

# 🔒 Get Defender Status Report

**Reports Microsoft Defender health across all Windows devices: protection state, signature age, and devices needing attention.**

This script reads the tenant-wide device protection overview and the per-device
    Windows protection state to report Microsoft Defender health: real-time
    protection, tamper protection, malware protection, signature currency, overdue
    scans, pending reboots, and devices whose state is not clean.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Defender Status Report** is a PowerShell script that This script reads the tenant-wide device protection overview and the per-device Windows protection state to report Microsoft Defender health: real-time protection, tamper protection, malware protection, signature currency, overdue scans, pending reboots, and devices whose state is not clean. Use it to find the machines on which Defender is silently off or outdated before they become incident tickets. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

This script reads the tenant-wide device protection overview and the per-device Windows protection state to report Microsoft Defender health: real-time protection, tamper protection, malware protection, signature currency, overdue scans, pending reboots, and devices whose state is not clean. Use it to find the machines on which Defender is silently off or outdated before they become incident tickets. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Reports Defender health across all Windows devices: real-time protection, tamper, signature age
* Flags overdue scans, pending reboot, and `NotReported` devices
* Fetches tenant `deviceProtectionOverview` plus per-device `windowsProtectionState`
* Supports `-OnlyIssues "true"` filter and `-ExportToCsv` timestamped export
* Throttling-aware with per-device cost noted for large tenants

---

# 📂 Project Structure

```text
Get-DefenderStatusReport
│
├── Get-DefenderStatusReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\get-defender-status-report.ps1
```
Reports Defender health for all Windows devices

### Example 2
```powershell
.\get-defender-status-report.ps1 -OnlyIssues "true"
```
Lists only devices with at least one Defender health issue

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ExportToCsv` / `ExportPath` / `OnlyIssues` | String | No | `false` | Export or filter switches per tool |
| `TenantId` | String | No | `` | Tenant ID for app-only auth |
| `ClientId` | String | No | `` | Client ID for app-only auth |
| `ClientSecret` | String | No | `` | Client secret (or use `CertificateThumbprint`) |
| `CertificateThumbprint` | String | No | `` | Certificate thumbprint for app-only auth |
| Common switches | String | No | — | Tool-specific flags described in EXAMPLES — see Usage above |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure (validation or Graph error) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Modules
* `Microsoft.Graph.Authentication` (auto-installed if missing; `MgGraphCommunity >= 1.4.0` for WAM-free interactive sign-in)

### Permissions
* `DeviceManagementManagedDevices.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\get-defender-status-report\Logs`

---

# 🛡️ Operational Notes

* All Security Tools run **LocalOnly** from an admin workstation via Microsoft Graph — interactive delegated (WAM-free via `MgGraphCommunity`) or app-only (`-TenantId`/`-ClientId`/`-ClientSecret` or `-CertificateThumbprint`) — with no Azure Automation dependency.
* Per-script least-privilege Graph permissions; consent on first interactive sign-in or pre-consent via Entra Enterprise Applications.
* Beta Graph endpoints where the surface requires it; paging with 429 throttling and one retry after 60s.
* Test in a staging tenant/device group before production; all scripts disconnect (`Disconnect-MgGraph` / `Disconnect-MgGraphCommunity`) and write structured logs.

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
