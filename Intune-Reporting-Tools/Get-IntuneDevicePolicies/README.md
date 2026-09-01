<div align="center">

# 📊 Get Intune Device Policies

**Retrieve all Intune policies assigned to a specific device via group memberships or All Devices/Users.**

This script finds every policy assigned to a device via transitive group memberships, All Devices, or All Users, covering configuration, compliance, scripts, endpoint security, update rings, and app assignments.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Device Policies** is a PowerShell reporting script that Queries Microsoft Graph to find every policy assigned to a device via group memberships, All Devices, or All Users. Covers device configuration, settings catalog, compliance, group policy, scripts, remediation, app configuration, Autopilot, endpoint security intents, update rings, feature/driver/quality updates, and app assignments with structured CSV/JSON output. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Resolves device and user transitive group memberships
* Matches assignments including All Devices/Users and group targets
* Scans configuration, compliance, scripts, and endpoint security
* Covers update rings, feature/driver/quality updates, and apps
* Exports CSV and JSON for analysis workflows

---

# 📂 Project Structure

```text
Get-IntuneDevicePolicies
│
├── Get-IntuneDevicePolicies.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneDevicePolicies.ps1 -DeviceName "L-PF4Z0HM0"
```

*Lists every policy assigned to the device*

### Example 2
```powershell
.\Get-IntuneDevicePolicies.ps1 -DeviceId "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```
Lookup by managed device ID

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceName` | string | Yes (ByName) | - | The Intune device name. |
| `DeviceId` | string | Yes (ById) | - | The Intune managed device ID (GUID). |
| `ExportPath` | string | No | - | Optional. Export results to CSV. |
| `OutputFindings` | bool | No | true | Register results as findings for diagnostic report. |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success |
| 1 | Failure |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Permissions
* `DeviceManagementConfiguration.Read.All,DeviceManagementManagedDevices.Read.All,DeviceManagementServiceConfig.Read.All,Device.Read.All,Directory.Read.All,Group.Read.All,GroupMember.Read.All,DeviceManagementApps.Read.All`

### Logging
* `C:\ProgramData\get-intune-device-policies\Logs`

---

# 🛡 Operational Notes
* Transitive membership resolution requires Directory.Read.All and GroupMember.Read.All; large groups may take time.
* All Devices and All Licensed Users targets match unconditionally; verify exclusion groups if expecting no policy.
* Test in a staging tenant first; Graph permission errors surface as 403 — check Entra consent for the listed scopes.

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