<div align="center">

# 📱 Get Devices by Scope Tag Report

**Generates comprehensive device reports filtered by Scope Tags with CSV and HTML export options**

This script connects to Microsoft Graph and retrieves all managed devices from Intune,
    filtering them by specified Scope Tags.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Devices by Scope Tag Report** is a PowerShell script that This script connects to Microsoft Graph and retrieves all managed devices from Intune, filtering them by specified Scope Tags. It generates detailed reports showing device status, owner information, enrollment profiles, compliance state, and other critical data. The script supports both CSV and HTML output formats, with the HTML report featuring a management-friendly styled interface. Ideal for multi-school environments or organizations using Scope Tags for administrative delegation, this script helps analyze device distribution and status across different organizational units. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

This script connects to Microsoft Graph and retrieves all managed devices from Intune, filtering them by specified Scope Tags. It generates detailed reports showing device status, owner information, enrollment profiles, compliance state, and other critical data. The script supports both CSV and HTML output formats, with the HTML report featuring a management-friendly styled interface. Ideal for multi-school environments or organizations using Scope Tags for administrative delegation, this script helps analyze device distribution and status across different organizational units. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Scope Tag-filtered Intune device inventory with HTML + CSV export
* Compliance state and platform filters with cached scope-tag resolution
* Paginated collection via Get-MgGraphAllPages with retry-aware 429 handling
* Interactive dashboard-style HTML report
* Beta endpoints where the Scope Tag surface requires it

---

# 📂 Project Structure

```text
Get-DevicesByScopeTag
│
├── Get-DevicesByScopeTag.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\get-devices-by-scopetag.ps1 -IncludeScopeTag "School_A"
```
Gets all devices with the "School_A" scope tag and exports CSV and HTML reports to current directory

### Example 2
```powershell
.\get-devices-by-scopetag.ps1 -IncludeScopeTag "School_A,School_B" -ExportPath "C:\Reports"
```
Gets devices from School_A and School_B, exports to both CSV and HTML in the specified directory

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
* `DeviceManagementManagedDevices.Read.All,DeviceManagementRBAC.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\get-devices-by-scopetag\Logs`

---

# 🛡️ Operational Notes

* Remote bulk operations support `-DryRun` / `-WhatIf` previews — use them before any write or destructive action.
* Graph scripts honor HTTP 429 throttling with 60-second back-off and support pagination via `Get-MgGraphAllPages`.
* CSV bulk operations are idempotent; re-running the same CSV without changes is a no-op.
* Test in a staging tenant or on a pilot Entra group before production; export reports for change control.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

**Mohammad Abdelkader Omar** (maintainer) — original author: **Ugur Koc**  
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
