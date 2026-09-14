<div align="center">

# 📱 Get Windows 11 Readiness Report

**Reports Windows 11 upgrade readiness for all Windows devices using Endpoint Analytics hardware signals.**

This script reads the Endpoint Analytics work-from-anywhere device data to report
    which Windows devices are eligible for Windows 11 and which hardware checks are
    blocking the rest: TPM, Secure Boot, RAM, storage, processor family, speed, core
    count, and 64-bit capability.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Windows 11 Readiness Report** is a PowerShell script that This script reads the Endpoint Analytics work-from-anywhere device data to report which Windows devices are eligible for Windows 11 and which hardware checks are blocking the rest: TPM, Secure Boot, RAM, storage, processor family, speed, core count, and 64-bit capability. It shows the tenant-level readiness summary plus a per-device breakdown of failed checks, so upgrade waves and hardware refresh budgets can be planned from real inventory data. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

This script reads the Endpoint Analytics work-from-anywhere device data to report which Windows devices are eligible for Windows 11 and which hardware checks are blocking the rest: TPM, Secure Boot, RAM, storage, processor family, speed, core count, and 64-bit capability. It shows the tenant-level readiness summary plus a per-device breakdown of failed checks, so upgrade waves and hardware refresh budgets can be planned from real inventory data. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Windows 11 upgrade readiness via Endpoint Analytics hardware signals
* Checks TPM, Secure Boot, RAM, storage, CPU family/speed/cores, and 64-bit
* Tenant summary plus per-device failed-check breakdown
* Optional CSV export for upgrade planning
* Read-only, no device state change

---

# 📂 Project Structure

```text
Get-Windows11Readiness
│
├── Get-Windows11Readiness.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\get-windows11-readiness-report.ps1
```
Shows the tenant readiness summary and all devices with failed upgrade checks

### Example 2
```powershell
.\get-windows11-readiness-report.ps1 -ExportToCsv "true"
```
Exports the full per-device readiness data to a timestamped CSV file

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
* `DeviceManagementManagedDevices.Read.All,DeviceManagementConfiguration.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\get-windows11-readiness-report\Logs`

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
