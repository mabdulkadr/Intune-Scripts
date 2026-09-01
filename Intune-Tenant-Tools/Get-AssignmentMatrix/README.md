<div align="center">

# 🏢 Get Assignment Matrix

**Builds a who-gets-what matrix of every policy, profile, script, and app.**

Flattens every Intune assignment into a single `Surface / Name / TargetType / GroupName / Intent / FilterName / FilterMode` row — answers what any group actually gets.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.3.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get Assignment Matrix** is a PowerShell script that collects assignments across seven Intune surfaces — device configurations, settings catalog, compliance, ADMX, platform scripts, remediation scripts, and applications — and flattens each assignment into one row showing target (group, all users/devices, or exclusion), resolved group name (cached), assignment filter with mode, and app install intent.

---

# ✨ Features

* One-row-per-assignment matrix across 7 surfaces with `Surface / Name / TargetType / GroupName / Intent / FilterName / FilterMode` columns
* Cached group-name resolution (deleted groups show as object ID) with optional `-IncludeUnassigned` for unassigned objects
* App intent and filter mode preserved per assignment
* Throttling-aware pagination (`Get-MgGraphAllPages` + retry) on beta Graph endpoints
* Optional timestamped CSV export beside the script

---

# 📂 Project Structure

```text
Get-AssignmentMatrix
│
├── Get-AssignmentMatrix.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-AssignmentMatrix.ps1
```
Shows the assignment matrix for all surfaces in the console.

### With Parameters
```powershell
.\Get-AssignmentMatrix.ps1 -Surfaces Apps,CompliancePolicies -IncludeUnassigned "true" -ExportToCsv "true"
```
Reports only apps and compliance policies including unassigned objects and exports to CSV; add app-only credentials for scheduled runs.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Surfaces | String[] | No | All surfaces | Assignment surfaces to include: DeviceConfigurations, SettingsCatalog, CompliancePolicies, AdmxPolicies, PlatformScripts, Remediations, Apps |
| IncludeUnassigned | String | No | false | When `"true"`, includes objects that have no assignments (useful for app catalog) |
| ExportToCsv | String | No | false | When `"true"`, exports the full matrix to a timestamped CSV file |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Matrix built — rows shown / exported |
| 1    | Script error (authentication or Graph collection failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All`, `Group.Read.All` (delegated or application); Intune Administrator.

### Logging
* `C:\ProgramData\get-assignment-matrix-report\Logs\`

---

# 🛡 Operational Notes

* Apps without assignments are skipped unless `-IncludeUnassigned` is used — the app catalog contains many built-in unassigned entries.
* Group names are resolved once and cached; deleted groups appear as their object ID.
* Beta Graph endpoints are used for assignment surfaces not yet on `v1.0`; all collections page fully and retry on 429/503.
* **Restore ShouldProcess note (tenant governance):** companion restore script gates every create with `ShouldProcess`; matrix output helps validate what assignments would be restored with `-RestoreAssignments`.
* RBAC sensitivity: matrix CSV reveals who gets what — treat as sensitive and restrict distribution.

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
