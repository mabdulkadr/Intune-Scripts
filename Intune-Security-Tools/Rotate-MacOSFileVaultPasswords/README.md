<div align="center">

# 🔒 Rotate macOS LAPS Passwords

**Rotates Local Administrator Password Solution (LAPS) passwords for macOS devices in Intune using Graph API.**

This script connects to Intune via Microsoft Graph API and rotates the LAPS passwords for managed macOS devices.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Rotate macOS LAPS Passwords** is a PowerShell script that This script connects to Intune via Microsoft Graph API and rotates the LAPS passwords for managed macOS devices. The script retrieves all macOS devices from Intune and triggers LAPS password rotation for each device. It provides real-time feedback on the rotation process, handles errors gracefully, and generates detailed reports. The script supports filtering by device groups, individual devices, or processing all macOS devices. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

This script connects to Intune via Microsoft Graph API and rotates the LAPS passwords for managed macOS devices. The script retrieves all macOS devices from Intune and triggers LAPS password rotation for each device. It provides real-time feedback on the rotation process, handles errors gracefully, and generates detailed reports. The script supports filtering by device groups, individual devices, or processing all macOS devices. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Rotates macOS LAPS/FileVault local admin passwords via Graph `rotateLocalAdminPassword`
* Personal devices (`ownerType == personal`) skipped — LAPS not supported
* Supports `-TestMode "true"` (no rotation, reports intent), `-DeviceName`/`-DeviceId`, `-DeviceLimit`, `-ExportReport`
* `-Force "true"` skips confirmation for automation; throttling retried once after 60s
* Workstation LocalOnly — interactive or app-only

---

# 📂 Project Structure

```text
Rotate-MacOSFileVaultPasswords
│
├── Rotate-MacOSFileVaultPasswords.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Rotate-MacOSFileVaultPasswords.ps1
```
Rotates LAPS passwords for all macOS devices in Intune

### Example 2
```powershell
.\Rotate-MacOSFileVaultPasswords.ps1 -DeviceName "MacBook-001"
```
Rotates LAPS password for a specific device

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceName` | String | No | `` | Specific macOS device name |
| `DeviceId` | String | No | `` | Specific Intune device ID |
| `DeviceLimit` | Int | No | `0` | Limit number of devices for rollout |
| `TestMode` | String | No | `false` | No rotation, reports intent (`"true"`) |
| `Force` | String | No | `false` | Skip confirmation (`"true"`) |
| `ExportReport` | String | No | `` | CSV export path |

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
* `DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.ReadWrite.All,DeviceManagementConfiguration.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\Rotate-MacOSFileVaultPasswords\Logs`

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
