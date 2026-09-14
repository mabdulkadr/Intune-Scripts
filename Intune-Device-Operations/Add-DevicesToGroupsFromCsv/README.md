<div align="center">

# 📱 Add Devices to Entra ID Groups from CSV

**Adds Intune-managed devices to Entra ID groups based on a CSV file input.**

This script reads a CSV file containing device identifiers and group names, then adds
    the specified devices to their corresponding Entra ID groups.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Add Devices to Entra ID Groups from CSV** is a PowerShell script that This script reads a CSV file containing device identifiers and group names, then adds the specified devices to their corresponding Entra ID groups. It supports multiple device identifiers (Device Name, Serial Number, Entra ID Device ID) for flexible device matching and can add devices to multiple groups. The script validates that devices exist in Intune before processing, checks for existing group memberships to avoid duplicates, and can create new groups with user confirmation. A dry-run mode allows previewing changes before execution. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

This script reads a CSV file containing device identifiers and group names, then adds the specified devices to their corresponding Entra ID groups. It supports multiple device identifiers (Device Name, Serial Number, Entra ID Device ID) for flexible device matching and can add devices to multiple groups. The script validates that devices exist in Intune before processing, checks for existing group memberships to avoid duplicates, and can create new groups with user confirmation. A dry-run mode allows previewing changes before execution. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* CSV-driven Entra ID group membership with DeviceId > SerialNumber > DeviceName priority and delimiter auto-detection
* Idempotent skip-if-already-member with per-group membership cache and optional auto-create
* Supports `-DryRun` preview and `-WhatIf` safe simulation for every row
* Dual auth: interactive delegated (MgGraphCommunity, WAM-free) and app-only (client secret or certificate)
* Structured logging with per-row result and retry-aware 429 throttling

---

# 📂 Project Structure

```text
Add-DevicesToGroupsFromCsv
│
├── Add-DevicesToGroupsFromCsv.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\add-devices-to-groups-from-csv.ps1 -GenerateTemplate "true"
```
Creates a template CSV file using your system's default delimiter (automatically comma for US, semicolon for Europe)

### Example 2
```powershell
.\add-devices-to-groups-from-csv.ps1 -GenerateTemplate "true" -TemplatePath "C:\templates\mytemplate.csv"
```
Creates a template CSV file at the specified path with system default delimiter

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `CsvPath` | String | No | `` | Path to CSV containing device and group information |
| `CsvContent` | String | No | `` | CSV text directly (workstation) |
| `GenerateTemplate` | String | No | `false` | Create template CSV (`"true"`) |
| `DryRun` | String | No | `false` | Preview without writes (`"true"`) |
| `CreateMissingGroups` | String | No | `false` | Auto-create missing Entra groups |
| `TenantId` / `ClientId` / `ClientSecret` / `CertificateThumbprint` | String | No | `` | App-only auth; omit for interactive |

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
* `Group.ReadWrite.All,DeviceManagementManagedDevices.Read.All,Directory.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\add-devices-to-groups-from-csv\Logs`

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
