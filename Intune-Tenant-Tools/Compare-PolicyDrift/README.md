<div align="center">

# 🏢 Compare Policy Drift

**Compares a baseline backup against live tenant state to surface configuration drift.**

Detects added, modified, or deleted settings catalog, configuration, and compliance policies by normalized JSON comparison — built for tenant change control.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Compare Policy Drift** is a PowerShell script that compares a baseline folder created by `Backup-IntuneConfiguration` against the tenant current state for settings catalog, configuration profiles, and compliance policies using normalized JSON (volatile `lastModifiedDateTime`, `version`, `assignments` removed) and classifies each object as `Added` / `Modified` / `Deleted` for change-control visibility.

---

# ✨ Features

* ID-matched comparison via `manifest.json` — a deleted-then-recreated policy appears as one deletion plus one addition
* Normalized JSON diff excludes timestamps, version counters, and assignment state so only configuration content counts as drift
* Covers settings catalog (full setting bodies), classic device configuration profiles, and compliance policies
* Optional CSV export (`-ExportToCsv "true"`) with timestamped file beside the script
* Workstation dual-mode auth (interactive or `-TenantId`/`-ClientId` app-only) with retry-aware Graph pagination

---

# 📂 Project Structure

```text
Compare-PolicyDrift
│
├── Compare-PolicyDrift.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Compare-PolicyDrift.ps1 -BaselinePath ".\IntuneConfigBackup_2026-07-01_08-00-00"
```
Compares the current tenant state against the July 1st baseline and shows drift in the console.

### With Parameters
```powershell
.\Compare-PolicyDrift.ps1 -BaselinePath ".\IntuneConfigBackup_2026-07-01_08-00-00" -ExportToCsv "true" -OutputPath "."
```
Exports the drift report to a timestamped CSV beside the script; add `-TenantId`/`-ClientId`/`-ClientSecret` for unattended runs.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| BaselinePath | String | Yes | - | Path to a baseline folder created by Backup-IntuneConfiguration.ps1 (must contain manifest.json) |
| ExportToCsv | String | No | false | When `"true"`, exports the drift report to a timestamped CSV file |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing Microsoft.Graph modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Drift analysis completed — results shown / exported |
| 1    | Script error (missing baseline, authentication, or Graph failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.Read.All` (delegated or application with admin consent); reads settings catalog, configuration, and compliance surfaces on beta Graph.

### Logging
* `C:\ProgramData\get-policy-drift-report\Logs\`

---

# 🛡 Operational Notes

* **Baseline requirement:** baseline must be a folder created by `Backup-IntuneConfiguration`; objects are matched by ID so renames are not treated as modifications.
* Volatile properties (`lastModifiedDateTime`, `version`, `assignments`) are stripped before comparison — only configuration content triggers `Modified`.
* RBAC and assignment state are not considered drift; use Assignment Matrix / Filter Audit for assignment visibility.
* Large tenants page with `Get-MgGraphAllPages` and retry on 429/503 (`Retry-After` up to 60s); do not abort on throttling messages.
* Export CSV is timestamped and written beside the script; test comparison in a staging tenant when validating change windows.

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
