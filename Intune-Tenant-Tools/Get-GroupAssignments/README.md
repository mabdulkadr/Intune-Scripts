<div align="center">

# 🏢 Get Group Assignments

**Lists everything Intune assigns to a single Entra ID group.**

Answers `what does this group get` across all Intune surfaces — profiles, policies, scripts, and apps with exclusion and tenant-wide context.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.3.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get Group Assignments** is a PowerShell script that takes an Entra ID group by display name or object ID (exact match required) and scans all major Intune assignment surfaces to show exactly what that group receives — configuration profiles, settings catalog, compliance, ADMX, platform scripts, remediation scripts, and applications with install intents — flagging exclusions and optionally including tenant-wide All Users / All Devices assignments.

---

# ✨ Features

* Single-group focus: exact-match lookup by `-GroupName` or `-GroupId` (use ID when names are ambiguous)
* Covers 7 surfaces with `Included` / `Excluded` / `All Users` / `All Devices` classification and filter mode per assignment
* Optional `-IncludeTenantWide` to show effective surface including tenant-wide assignments
* Nested group inheritance is not evaluated — only direct assignments to the given group are shown
* Optional CSV export and dual-mode workstation auth

---

# 📂 Project Structure

```text
Get-GroupAssignments
│
├── Get-GroupAssignments.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-GroupAssignments.ps1 -GroupName "Sales Devices"
```
Lists everything assigned to the group named Sales Devices in the console.

### With Parameters
```powershell
.\Get-GroupAssignments.ps1 -GroupId "d0eea876-63b4-4e74-bff8-d11daf12b2f3" -IncludeTenantWide "true" -ExportToCsv "true"
```
Lists assignments for the group by ID including tenant-wide assignments and exports to CSV.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| GroupName | String | No | None | Display name of the Entra ID group (must match exactly one group) |
| GroupId | String | No | None | Object ID of the Entra ID group (preferred when names are ambiguous) |
| IncludeTenantWide | String | No | false | When `"true"`, also lists tenant-wide All Users / All Devices assignments |
| ExportToCsv | String | No | false | When `"true"`, exports the group assignment list to a timestamped CSV file |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Group assignments listed — results shown / exported |
| 1    | Script error (group not found, authentication, or Graph failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All`, `GroupMember.Read.All` (delegated or application).

### Logging
* `C:\ProgramData\get-group-assignments\Logs\`

---

# 🛡 Operational Notes

* Group name lookup must match exactly one group; use `-GroupId` when names are ambiguous or duplicated.
* Nested group inheritance is not evaluated; only direct assignments to the given group are shown — combine with Assignment Matrix for transitive analysis.
* Beta Graph endpoints are used for assignment surfaces; pagination and retry honor `Retry-After`.
* **RBAC sensitivity (tenant governance):** group-assignment output maps blast radius of a group — treat as sensitive; companion RBAC audit uses `DeviceManagementRBAC.Read.All` for access reviews.
* Relative `-OutputPath` values resolve beside the script; test queries in a staging tenant before exporting production data.

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
