<div align="center">

# 📊 Get Intune Autopilot Report

**Report Autopilot device registration and deployment profile status.**

This script lists all Autopilot registered devices with profile assignment state, group tag, deployment profile, purchase order, serial number, and enrollment status.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Autopilot Report** is a PowerShell reporting script that Lists all Autopilot registered devices with their profile assignment state, group tag, deployment profile, purchase order, serial number, and enrollment status. Identifies devices registered but not enrolled, devices with no profile assigned, and deployment errors. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Inventory of Autopilot device identities and profiles
* Cross-references with Intune enrolled devices
* Breakdown of profile assignment and enrollment health
* Group tag and model distribution summaries
* Exports CSV for provisioning audits

---

# 📂 Project Structure

```text
Get-IntuneAutopilotReport
│
├── Get-IntuneAutopilotReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneAutopilotReport.ps1
```

*Reports Autopilot device inventory*

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ExportPath` | string | No | - | Optional. Export to CSV at the specified path. |

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
* `DeviceManagementServiceConfig.Read.All,DeviceManagementManagedDevices.Read.All`

### Logging
* `C:\ProgramData\get-intune-autopilot-report\Logs`

---

# 🛡 Operational Notes
* Autopilot registration does not guarantee enrollment; compare ProfileStatus and IsEnrolled to find provisioning gaps.
* Group tag distribution reflects deployment grouping; empty tags indicate ungrouped devices.
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