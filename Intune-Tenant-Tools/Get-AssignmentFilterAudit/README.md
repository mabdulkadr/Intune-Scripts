<div align="center">

# 🏢 Get Assignment Filter Audit

**Audits assignment filters and flags unused or duplicated rules.**

Cross-references every assignment surface for filter references to report unused and duplicate filters — built for Intune filter hygiene.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.3.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get Assignment Filter Audit** is a PowerShell script that retrieves all Intune assignment filters and cross-references them against every assignment surface that can carry a filter — configuration profiles, settings catalog, compliance, ADMX, platform scripts, remediation scripts, and applications — reporting which filters are unused and which duplicate each other (same platform + whitespace-normalized rule) so stale filters can be cleaned safely.

---

# ✨ Features

* Scans seven assignment surfaces for `deviceAndAppManagementAssignmentFilterId` / `Type` references (include and exclude modes)
* Duplicate detection compares platform plus whitespace-normalized rule text
* Reports unused filters (zero references) and duplicate filter groups in one run
* Cached group-name resolution is not needed — focus is pure filter-to-assignment mapping
* Optional CSV export and workstation dual-mode auth with throttling-aware pagination

---

# 📂 Project Structure

```text
Get-AssignmentFilterAudit
│
├── Get-AssignmentFilterAudit.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-AssignmentFilterAudit.ps1
```
Shows the filter audit in the console — counts of used, unused, and duplicate filters.

### With Parameters
```powershell
.\Get-AssignmentFilterAudit.ps1 -ExportToCsv "true" -OutputPath "."
```
Exports the filter audit to a timestamped CSV beside the script; add `-TenantId`/`-ClientId` for app-only.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| ExportToCsv | String | No | false | When `"true"`, exports the filter audit to a timestamped CSV file |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing Microsoft.Graph modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Audit completed — unused and duplicate filters reported |
| 1    | Script error (authentication or Graph inventory failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All` (delegated or application); Intune Administrator recommended.

### Logging
* `C:\ProgramData\get-assignment-filter-audit\Logs\`

---

# 🛡 Operational Notes

* Filters are counted as used when at least one assignment references them in include or exclude mode; the script only reports — deleting filters remains a manual decision.
* Duplicate detection is platform + rule exact after whitespace normalization; rule edits that change semantics are not flagged as duplicates.
* **Backup depth 25 note (tenant-wide):** filter audit complements backup/restore governance; backup exports use `ConvertTo-Json -Depth 25` so filter references survive round-tripping.
* All queries run on beta Graph endpoints; pagination via `Get-MgGraphAllPages` with 429/503 retry honoring `Retry-After`.
* RBAC sensitivity: filter audit output reveals assignment targeting logic — treat CSV as sensitive.

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
