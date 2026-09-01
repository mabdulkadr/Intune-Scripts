<div align="center">

# 📊 Get Intune Device Timeline

**Show a comprehensive timeline of everything that happened to a single device.**

This script pulls enrollment info, compliance evaluations, configuration states, detected apps, hardware details, and Defender status for a single device as a chronological timeline.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Device Timeline** is a PowerShell reporting script that Pulls all available data for one device: enrollment info, compliance evaluations, configuration profile states, app installation status, script execution results, detected apps, and hardware details. Presents as a chronological timeline for troubleshooting what changed on this device. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Collects enrollment, compliance, and configuration states
* Lists detected apps and hardware information
* Shows Defender protection state per device
* Builds chronological timeline sorted newest-first
* Exports timeline to CSV for forensic review

---

# 📂 Project Structure

```text
Get-IntuneDeviceTimeline
│
├── Get-IntuneDeviceTimeline.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneDeviceTimeline.ps1 -DeviceName "CYBR-PW00K4WR"
```

*Shows timeline for a single device*

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceName` | string | Yes | - | The Intune device name. |
| `ExportPath` | string | No | - | Optional. Export timeline to CSV. |

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
* `DeviceManagementManagedDevices.Read.All,DeviceManagementConfiguration.Read.All,DeviceManagementApps.Read.All,Device.Read.All`

### Logging
* `C:\ProgramData\get-intune-device-timeline\Logs`

---

# 🛡 Operational Notes
* Timeline aggregates multiple Graph endpoints; single endpoint failure does not abort the report — check warnings.
* Hardware and Defender data may be unavailable for recently enrolled or non-Windows devices.
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