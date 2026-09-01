<div align="center">

# 📱 Cleanup Orphaned Autopilot Devices

**Remove devices from Autopilot that are no longer managed in Intune**

This script connects to Microsoft Graph and identifies Windows Autopilot devices that are
    registered in the Autopilot service but are no longer present as managed devices in Intune.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Cleanup Orphaned Autopilot Devices** is a PowerShell script that This script connects to Microsoft Graph and identifies Windows Autopilot devices that are registered in the Autopilot service but are no longer present as managed devices in Intune. These orphaned devices can accumulate over time when devices are retired, reimaged, or replaced without proper cleanup of the Autopilot registration. The script provides options to preview orphaned devices before removal and supports batch operations with confirmation prompts for safety. It helps maintain a clean Autopilot device inventory and prevents potential enrollment issues. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

This script connects to Microsoft Graph and identifies Windows Autopilot devices that are registered in the Autopilot service but are no longer present as managed devices in Intune. These orphaned devices can accumulate over time when devices are retired, reimaged, or replaced without proper cleanup of the Autopilot registration. The script provides options to preview orphaned devices before removal and supports batch operations with confirmation prompts for safety. It helps maintain a clean Autopilot device inventory and prevents potential enrollment issues. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Finds Autopilot registrations whose serial numbers no longer exist in Intune managed devices
* `-PreviewOnly "true"` gate before any delete with sanitized `0001-01-01` dates shown as Never
* Throttled batch deletes with `-RemoveOrphaned "true" -Force "true"` explicit consent
* Export orphan list via `-ExportPath` for change control
* Beta endpoints for Autopilot, read-optimized projections

---

# 📂 Project Structure

```text
Remove-StaleAutopilotDevices
│
├── Remove-StaleAutopilotDevices.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\cleanup-autopilot-devices.ps1 -PreviewOnly "true"
```
Shows orphaned Autopilot devices without removing them

### Example 2
```powershell
.\cleanup-autopilot-devices.ps1 -RemoveOrphaned "true" -ExportPath "C:\Reports\removed-autopilot-devices.csv"
```
Removes orphaned devices and exports the list to CSV

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `PreviewOnly` | String | No | `true` | Show orphans without deleting (`"true"`) |
| `RemoveOrphaned` | String | No | `false` | Delete orphans (`"true"` requires `-Force "true"`) |
| `Force` | String | No | `false` | Confirm destructive delete (`"true"`) |
| `ExportPath` | String | No | `` | CSV path to export orphan list |
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
* `DeviceManagementServiceConfig.ReadWrite.All,DeviceManagementManagedDevices.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\cleanup-autopilot-devices\Logs`

---

# 🛡️ Operational Notes

* **Autopilot cleanup — preview is mandatory.** Always run `Remove-StaleAutopilotDevices.ps1 -PreviewOnly "true"` first and export the orphan list (`-ExportPath`). Removal deletes the Autopilot registration itself; re-registration requires re-importing the hardware hash. Confirm expected serials before using `-RemoveOrphaned "true" -Force "true"`.
* Orphan detection compares Autopilot `serialNumber` against Intune managed-device serials; sanitized `0001-01-01` dates are shown as **Never**.
* Batch deletes are throttled; Graph 429 is retried once after 60s.
* This is a **DANGER — Deletes Autopilot** operation — use staged pilots and change control.

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
