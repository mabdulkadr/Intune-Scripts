<div align="center">

# 🔍 Get-ImeDiagnostics

**Parse Intune Management Extension logs into a Carbon Dark timeline**

Troubleshoot Win32App, ESP, and Remediation failures without CMTrace. Reads IntuneManagementExtension.log + AgentExecutor.log, exports Carbon Dark HTML.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#-parameters) • [License](#-license)

</div>

---

# 🔍 Overview

**Get-ImeDiagnostics** Troubleshoot Win32App, ESP, and Remediation failures without CMTrace. Reads IntuneManagementExtension.log + AgentExecutor.log, exports Carbon Dark HTML.

---

# ✨ Features

* Log Timeline - Parses IME XML-style log format and plain timestamped lines, categorizes events
* Carbon Dark HTML - KPI tiles + category breakdown + 500-event timeline table, no CDN dependency
* Event Log Fallback - Falls back to Microsoft-Windows-DeviceManagement-Enterprise-Diagnostics-Provider when IME logs are absent

---

# 📂 Project Structure

```text
Get-ImeDiagnostics
│
├── Get-ImeDiagnostics.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
`powershell
.\Get-ImeDiagnostics.ps1
`

### With Parameters
`powershell
.\Get-ImeDiagnostics.ps1 -MaxLines 10000 -NoOpen
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
* C:\ProgramData\Get-ImeDiagnostics\Logs\

---

# 🛡 Operational Notes
* Default parses last 5000 lines per file; increase -MaxLines for deep investigations
* Runs locally; no Graph or tenant authentication required

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