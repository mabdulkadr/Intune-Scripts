<div align="center">

# 📱 Wipe Devices

**Perform remote wipe operations on specific managed devices in Intune or devices in an Entra ID group.**

DANGER - DESTRUCTIVE AND IRREVERSIBLE.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.7.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Wipe Devices** is a PowerShell script that DANGER - DESTRUCTIVE AND IRREVERSIBLE. This tool triggers remote wipes that permanently destroy data: a Full wipe factory-resets devices and erases ALL data with no recovery, and a Selective wipe (retire) removes company data, apps, and enrollment state. Wiped devices may be unrecoverable if BitLocker keys were not escrowed beforehand. There is no undo: always verify targets with -DryRun first, coordinate with affected users, and run this tool only when you can defend every target device. This script connects to Microsoft Graph and triggers remote wipe operations on targeted devices. You can target devices by specific names, device IDs, or by Entra ID group membership. The script provides options for selective wipe (remove company data) or full wipe (factory reset). All operations include confirmation prompts to prevent accidental data loss. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

DANGER - DESTRUCTIVE AND IRREVERSIBLE. This tool triggers remote wipes that permanently destroy data: a Full wipe factory-resets devices and erases ALL data with no recovery, and a Selective wipe (retire) removes company data, apps, and enrollment state. Wiped devices may be unrecoverable if BitLocker keys were not escrowed beforehand. There is no undo: always verify targets with -DryRun first, coordinate with affected users, and run this tool only when you can defend every target device. This script connects to Microsoft Graph and triggers remote wipe operations on targeted devices. You can target devices by specific names, device IDs, or by Entra ID group membership. The script provides options for selective wipe (remove company data) or full wipe (factory reset). All operations include confirmation prompts to prevent accidental data loss. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Selective (retire) or Full (factory reset) wipe by device names, IDs, or Entra group
* Supports `keepEnrollmentData`, macOS PIN handling, and per-device wipe delays
* Portal-safe string-boolean parameters with typed validation
* `DryRun` preview and explicit `CONFIRM` gate before any destructive call
* Throttled retries on Graph 429 with per-device result tracking

---

# 📂 Project Structure

```text
Invoke-DeviceWipe
│
├── Invoke-DeviceWipe.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\wipe-devices.ps1 -DeviceNames "LAPTOP001","DESKTOP002" -WipeType Selective
```
Performs selective wipe on specific devices by name

### Example 2
```powershell
.\wipe-devices.ps1 -DeviceIds "12345678-1234-1234-1234-123456789012" -WipeType Full -Force "true"
```
Performs full wipe on a specific device by ID without confirmation

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceNames` | String[] | No | `` | Target by Intune device names |
| `DeviceIds` | String[] | No | `` | Target by Intune device IDs |
| `GroupName` / `GroupId` | String | No | `` | Target by Entra ID group (requires `GroupMember.Read.All`) |
| `WipeType` | String | No | `Selective` | `Selective` (retire) or `Full` (factory reset) |
| `DryRun` | String | No | `false` | Preview targets without wiping (`"true"`) |
| `Force` | String | No | `false` | Skip CONFIRM prompt (`"true"`) — use in automation only |
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
* `DeviceManagementManagedDevices.PrivilegedOperations.All,DeviceManagementManagedDevices.Read.All,GroupMember.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\wipe-devices\Logs`

---

# 🛡️ Operational Notes

> ### 🔴 DANGER — `Invoke-DeviceWipe.ps1` is irreversible and has no undo
> A **Full** wipe factory-resets the device and permanently erases all user data, apps, and settings. A **Selective** wipe (retire) removes company data, managed apps, and enrollment state. In both cases the device may become unrecoverable. **Before any wipe:** confirm BitLocker recovery keys are escrowed in Entra ID, verify every target with `-DryRun "true"` (and `-WhatIf` where supported), coordinate with affected users, and require an explicit `CONFIRM` prompt (or intentional `-Force "true"` in automation). Never run wide-scope wipes without a second reviewer and a staged pilot.
>
> * Graph throttling is honored (HTTP 429) with 60-second back-off and per-device delays via `-WipeDelaySeconds`.
> * Group targeting resolves Entra group members via `GroupMember.Read.All` and records an empty group as a successful no-op.
> * macOS PIN applies only to macOS devices; a warning is emitted otherwise.
> * Always test in a staging tenant or on a pilot group before production.

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
