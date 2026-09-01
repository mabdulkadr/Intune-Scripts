<div align="center">

# 🧩 Get Duplicate Applications

**Identifies and reports duplicate applications across all managed applications in Intune.**

Scans every app uploaded to Intune, normalizes names, and flags duplicates — same name with different publishers, name variations, or different app types — exporting CSV and HTML to drive catalog hygiene.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get-DuplicateApplications** is a PowerShell script that finds duplicate applications in the Intune app catalog.

It pages all mobile apps via Microsoft Graph beta with selective fields, normalizes display names (stripping architecture suffixes, collapsing whitespace, lowercasing), groups by normalized name, and classifies duplicates into three types: multiple publishers for the same normalized name, multiple original name variations (case, spacing), and multiple app types for the same name. Results are surfaced as detailed per-app CSV rows and a grouped HTML report with badges and summary counts. Supports workstation dual-mode authentication: interactive sign-in (WAM-free via MgGraphCommunity) or app-only with tenant, client ID, and secret or certificate.

---

# ✨ Features

* Duplicate detection by normalized name, publisher, and app type
* Name normalization that removes x64, x86, 32-bit, 64-bit, and parenthetical suffixes
* Separate duplicate types: multiple publishers, name variations, and multiple app types
* Detailed CSV with per-app rows grouped by duplicate cluster and HTML report with badges
* Beta Graph paging with throttling backoff and single-element array preservation
* Workstation dual-mode Graph authentication
* Structured timestamped logging mirrored to disk

---

# 📂 Project Structure

```text
Get-DuplicateApplications
│
├── Get-DuplicateApplications.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-DuplicateApplications.ps1
```
Generates a duplicate applications report for all Intune applications.

### Custom Output Path
```powershell
.\Get-DuplicateApplications.ps1 -OutputPath "C:\Reports"
```
Generates the duplicate applications report and saves to the specified directory.

### Force Module Install
```powershell
.\Get-DuplicateApplications.ps1 -ForceModuleInstall "true"
```
Forces module installation without prompting and generates the report.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| OutputPath | String | No | "." | Output directory for CSV and HTML reports |
| ForceModuleInstall | String | No | "false" | Force Microsoft Graph module installation without prompting (true/false, 1/0) |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Microsoft Graph: `DeviceManagementApps.Read.All`
* Entra role: **Intune Administrator**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed when missing; prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` (auto-installed when available for WAM-free interactive sign-in)

### Logging
* `C:\ProgramData\get-duplicate-applications\Logs\`

---

# 🛡 Operational Notes

* Read-only reporting — analyzes the Intune app catalog only and creates no tenant objects.
* Analyzes applications uploaded to Intune, not device-installed application instances.
* Duplicate detection uses normalized names; review the grouped HTML view before any catalog merges.
* Uses beta Graph endpoints; paging honors HTTP 429 with a 60-second pause and preserves single-element arrays.
* Large catalogs are handled with throttling-aware paging; do not abort on the first rate-limit message.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

Migrated to Enterprise Admin standards by **Mohammad Abdelkader Omar**  
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
