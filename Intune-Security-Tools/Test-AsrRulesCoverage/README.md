<div align="center">

# 🛡 Test-AsrRulesCoverage

**Audit ASR rules and find gaps vs the Microsoft 25H2 baseline**

Inventories all 18 core ASR rules via Get-MpPreference (with registry fallback), maps each GUID to its friendly name, and compares the live state against the 25H2 baseline.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#-parameters) • [License](#-license)

</div>

---

# 🛡 Overview

**Test-AsrRulesCoverage** Inventories all 18 core ASR rules via Get-MpPreference (with registry fallback), maps each GUID to its friendly name, and compares the live state against the 25H2 baseline.

---

# ✨ Features

* 25H2 Baseline Gap Analysis - 18 rules including LSASS credential theft, PSExec/WMI, email content, Office injection, vulnerable drivers
* Local-First, Tenant-Optional - Pure local audit with no Graph; optional TenantId parameter for future Intune policy comparison
* Carbon Dark HTML - KPI tiles (Block/Audit/Not Configured/Coverage %) + per-rule GAP badge

---

# 📂 Project Structure

```text
Test-AsrRulesCoverage
│
├── Test-AsrRulesCoverage.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
`powershell
.\Test-AsrRulesCoverage.ps1
`

### With Parameters
`powershell
.\Test-AsrRulesCoverage.ps1 -MaxLines 10000 -NoOpen
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
* C:\ProgramData\Test-AsrRulesCoverage\Logs\

---

# 🛡 Operational Notes
* Run from an admin workstation or use -WhatIf on a single device first
* Large tenants take minutes; use -OnlyIssues to filter to actionable rows

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