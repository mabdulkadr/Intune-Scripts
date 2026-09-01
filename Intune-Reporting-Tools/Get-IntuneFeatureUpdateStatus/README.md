<div align="center">

# 📊 Get Intune Feature Update Status

**Report feature update profile deployment status per device.**

This script shows per-device deployment state for each feature update profile: offered, pending download, installing, pending reboot, installed, safeguard held, or error.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Feature Update Status** is a PowerShell reporting script that For each feature update profile, shows deployment state per device: offered, pending download, downloading, installing, pending reboot, installed, cancelled, safeguard held, or error. Identifies devices blocked by safeguard holds and those stuck in pending states. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Lists feature update profiles and assignments
* Reports per-device deviceUpdateStates with state distribution
* Identifies safeguard holds and error states
* Supports filtering by ProfileName
* Exports CSV with per-device deployment history

---

# 📂 Project Structure

```text
Get-IntuneFeatureUpdateStatus
│
├── Get-IntuneFeatureUpdateStatus.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneFeatureUpdateStatus.ps1
```

*Reports feature update status for all profiles*

### Example 2
```powershell
.\Get-IntuneFeatureUpdateStatus.ps1 -ProfileName "Windows 11 24H2"
```
Filters to a specific feature update profile

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ProfileName` | string | No | - | Optional. Filter to a specific feature update profile name. |
| `ExportPath` | string | No | - | Optional. Export to CSV. |

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
* `DeviceManagementConfiguration.Read.All`

### Logging
* `C:\ProgramData\get-intune-feature-update-status\Logs`

---

# 🛡 Operational Notes
* Feature update deviceUpdateStates may be delayed after profile creation; empty results indicate pending reporting.
* Safeguard holds are Microsoft-applied compatibility blocks — check Windows release health for details.
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