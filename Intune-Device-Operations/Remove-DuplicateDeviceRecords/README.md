<div align="center">

# 📱 Cleanup Duplicate Intune Device Records

**Finds Intune managed-device records that share a serial number and optionally removes the older stale duplicates.**

This script groups all Intune managed devices by serial number and identifies
    duplicates - typically left behind by re-enrollment, OS reinstalls, or Autopilot
    resets.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.3.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Cleanup Duplicate Intune Device Records** is a PowerShell script that This script groups all Intune managed devices by serial number and identifies duplicates - typically left behind by re-enrollment, OS reinstalls, or Autopilot resets. For every duplicate set it keeps the record with the most recent sync and marks the older records for cleanup. By default the script only reports; deletion requires the -Remove switch and is preview-safe via -WhatIf. Removing a device record from Intune does not wipe the device; it only deletes the stale management object. Scope is limited to Intune managed-device records returned by /deviceManagement/managedDevices. The script does not inspect or delete Microsoft Entra device objects or Windows Autopilot registrations. Duplicate-looking Entra objects can be expected with Hybrid Autopilot deployments and must not be treated as stale Intune records. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

This script groups all Intune managed devices by serial number and identifies duplicates - typically left behind by re-enrollment, OS reinstalls, or Autopilot resets. For every duplicate set it keeps the record with the most recent sync and marks the older records for cleanup. By default the script only reports; deletion requires the -Remove switch and is preview-safe via -WhatIf. Removing a device record from Intune does not wipe the device; it only deletes the stale management object. Scope is limited to Intune managed-device records returned by /deviceManagement/managedDevices. The script does not inspect or delete Microsoft Entra device objects or Windows Autopilot registrations. Duplicate-looking Entra objects can be expected with Hybrid Autopilot deployments and must not be treated as stale Intune records. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Groups Intune records by trimmed serial number and finds duplicates
* Keeps most-recent `lastSyncDateTime` (fallback `enrolledDateTime`) per serial
* Placeholder serials excluded (`Defaultstring`, `ToBeFilledByOEM`, `SystemSerialNumber`, `0`, `none`, `unknown`)
* Default report-only; deletion requires `-Remove "true"` with `-WhatIf` support
* Exports duplicate report and never touches Entra device objects or Autopilot registrations

---

# 📂 Project Structure

```text
Remove-DuplicateDeviceRecords
│
├── Remove-DuplicateDeviceRecords.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\cleanup-duplicate-device-records.ps1
```
Reports duplicate Intune managed-device records without deleting anything

### Example 2
```powershell
.\cleanup-duplicate-device-records.ps1 -Remove "true" -WhatIf
```
Shows exactly which Intune managed-device records would be deleted, without deleting them

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `Remove` | String | No | `false` | Delete older duplicates (`"true"`) — default report-only |
| `WhatIf` | Switch | No | — | Shows which records would be deleted without deleting |
| `ExportPath` | String | No | `` | CSV export for duplicate report |
| `TenantId` / `ClientId` / `ClientSecret` / `CertificateThumbprint` | String | No | `` | App-only auth |

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
* `DeviceManagementManagedDevices.ReadWrite.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\cleanup-duplicate-device-records\Logs`

---

# 🛡️ Operational Notes

* **Duplicate purge — keeper selection is deterministic.** `Remove-DuplicateDeviceRecords.ps1` keeps the record with the most recent `lastSyncDateTime` (falling back to `enrolledDateTime`) per trimmed serial number and marks all older records stale. Placeholder serials (`""`, `"Defaultstring"`, `"ToBeFilledByOEM"`, `"SystemSerialNumber"`, `"0"`, `"none"`, `"unknown"`) are excluded. Default is report-only; deletion requires `-Remove "true"` (supports `-WhatIf`). Deleting an Intune record does not wipe the device — it only removes the stale management object; Entra device objects and Autopilot registrations are never touched.
* Run with `-WhatIf` first, export the report, and review keeper logic before destructive runs.
* Graph throttling (429) is honored with back-off.

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
