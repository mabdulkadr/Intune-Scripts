<div align="center">

# 🔥 Get-HotpatchReadiness

**Check Hotpatch eligibility for the May 2026 Default-ON rollout**

Hotpatch became Default-ON in May 2026 for supported SKUs. This tool checks the three prerequisites: Enterprise/Education SKU, VBS enabled, and Build >= 26100 (24H2+).

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#-parameters) • [License](#-license)

</div>

---

# 🔥 Overview

**Get-HotpatchReadiness** Hotpatch became Default-ON in May 2026 for supported SKUs. This tool checks the three prerequisites: Enterprise/Education SKU, VBS enabled, and Build >= 26100 (24H2+).

---

# ✨ Features

* Three-Pillar Gate - Validates SKU, VBS, and Build 26100+ - the three prerequisites Microsoft documented for Hotpatch Default-ON support
* Carbon Dark HTML - Outputs self-contained HTML readiness report with KPI tiles, sortable tables, and print-safe styles
* Read-Only - No remediation script - report-only audit

---

# 📂 Project Structure

```text
Get-HotpatchReadiness
│
├── Get-HotpatchReadiness.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
`powershell
.\Get-HotpatchReadiness.ps1
`

### With Parameters
`powershell
.\Get-HotpatchReadiness.ps1 -MaxLines 10000 -NoOpen
`

---

# ⚙ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| OutputPath | string | No | beside script Reports | Folder for HTML/CSV output |
| MaxLines | int | No | 5000 | Maximum log lines to parse per file |
| NoOpen | switch | No | off | Skip auto-opening the HTML report |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure |

---

# ⚙ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Standard user; elevation extends coverage to system-only paths.

### Logging
* C:\ProgramData\Get-HotpatchReadiness\Logs\

---

# 🛡 Operational Notes
* Requires Windows 10/11 on Enterprise or Education SKU - Pro is not eligible
* Local mode only; tenant Graph inventory is planned for a future version

---

## 👤 Author

**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

---

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