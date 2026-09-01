<div align="center">

# 📱 Sync All Intune Devices

**Sends the syncDevice command to every managed device enrolled in Intune via Microsoft Graph.**

Installs the Microsoft Graph Authentication module when missing, authenticates to Microsoft Graph
    interactively with an MFA-capable account, retrieves the full paginated list of managed devices,
    and posts a syncDevice action for each device so it checks back in with the service immediately.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Sync All Intune Devices** is a PowerShell script that Installs the Microsoft Graph Authentication module when missing, authenticates to Microsoft Graph interactively with an MFA-capable account, retrieves the full paginated list of managed devices, and posts a syncDevice action for each device so it checks back in with the service immediately. The session is disconnected when the run completes.

Installs the Microsoft Graph Authentication module when missing, authenticates to Microsoft Graph interactively with an MFA-capable account, retrieves the full paginated list of managed devices, and posts a syncDevice action for each device so it checks back in with the service immediately. The session is disconnected when the run completes. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Sends `syncDevice` to every managed device in the tenant in one burst
* Full pagination via `Get-MgGraphAllPages` with retry-aware 429/503 handling
* Interactive MFA and app-only (TenantID/AppID/AppSecret) authentication variants
* Per-device sync confirmation logged with timestamped, level-colored lines
* Strips legacy raw token echo for secret hygiene — tokens converted to SecureString

---

# 📂 Project Structure

```text
Sync-AllIntuneDevices
│
├── Sync-AllIntuneDevices.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Sync-AllIntuneDevices.ps1
```
Signs in interactively, then sends a sync request to every enrolled device.

### Example 2
```powershell
.\Sync-AllIntuneDevices.ps1 -Verbose
```
Same run with verbose preference; per-request details are also captured in the log file.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `TenantId` | String | No | `` | App-only: tenant ID (optional, interactive by default) |
| `AppId` | String | No | `` | App-only: application (client) ID |
| `AppSecret` | String | No | `` | App-only: client secret — supply from secret store at runtime |
| `Verbose` | Switch | No | — | Show verbose Graph progress |

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
* `Interactive sign-in requests these user scopes: CloudPC.ReadWrite.All, Domain.Read.All, Directory.Read.All, DeviceManagementConfiguration.ReadWrite.All, DeviceManagementManagedDevices.ReadWrite.All, openid, profile, email, offline_access, DeviceManagementManagedDevices.PrivilegedOperations.All.` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\Sync-AllIntuneDevices\Logs`

---

# 🛡️ Operational Notes

* Endpoints stay on the Graph **beta** service (`deviceManagement/managedDevices` + `syncDevice`), matching legacy behavior.
* Syncing every device at once creates a burst of check-ins — schedule off-hours.
* Legacy raw access-token console echo was removed for secret hygiene; tokens are converted to SecureString.
* Never hardcode client secrets; retrieve them at runtime from Azure Key Vault or SecretManagement.
* The session is disconnected from Microsoft Graph when the run completes.

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

