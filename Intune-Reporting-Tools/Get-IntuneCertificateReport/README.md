<div align="center">

# 📊 Get Intune Certificate Report

**Report certificate deployment status across Intune managed devices.**

This script lists all certificate profiles (SCEP, PKCS, trusted root) and their deployment status, identifying profiles with failures and overall certificate health.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Certificate Report** is a PowerShell reporting script that Lists all certificate profiles (SCEP, PKCS, trusted root) and their deployment status. Identifies profiles with failures and shows overall certificate health. It runs from a workstation via Microsoft Graph and writes structured logs for every operation.

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required.

---

# ✨ Features

* Filters device configurations to certificate profiles
* Reads per-profile deviceStatusOverview health counts
* Calculates success rate and flags failing profiles
* Checks Settings Catalog when no legacy profiles found
* Exports CSV for certificate health tracking

---

# 📂 Project Structure

```text
Get-IntuneCertificateReport
│
├── Get-IntuneCertificateReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneCertificateReport.ps1
```

*Reports certificate deployment status*

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
* `DeviceManagementConfiguration.Read.All`

### Logging
* `C:\ProgramData\get-intune-certificate-report\Logs`

---

# 🛡 Operational Notes
* Certificate profiles include SCEP, PKCS, and trusted root types; Settings Catalog policies are checked as fallback.
* Health percentages are based on succeeded vs total targeted devices per profile.
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