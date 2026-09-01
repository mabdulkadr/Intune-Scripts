<div align="center">

# 🏢 Get Intune Role Assignments

**Audits Intune RBAC — who has which roles, scopes, and members.**

Enumerates role definitions and assignments with resolved users and groups for access reviews — built for RBAC hygiene.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get Intune Role Assignments** is a PowerShell script that connects to Microsoft Graph to retrieve all Intune role definitions and their assignments, showing both built-in and custom roles, assigned users/groups, assignment dates, and scopes. Each assignment is fetched with `$expand=roleDefinition` because the list endpoint does not link assignments to roles, and principal lookups retry once after 60s on throttling.

---

# ✨ Features

* Enumerates `roleDefinitions` and `roleAssignments` grouped by role (built-in vs. custom) with scope and member details
* Resolves user and group principals with 429 retry; shows assignment dates where available
* Optional `-ShowEmptyRoles` to list roles with no current assignments
* Optional CSV export (flattened members per assignment) for access reviews
* Beta Graph endpoints with per-assignment `$expand` and retry-aware principal resolution

---

# 📂 Project Structure

```text
Get-IntuneRoleAssignments
│
├── Get-IntuneRoleAssignments.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-IntuneRoleAssignments.ps1
```
Shows all Intune role assignments — built-in and custom — with resolved members.

### With Parameters
```powershell
.\Get-IntuneRoleAssignments.ps1 -ShowEmptyRoles "true" -ExportToCsv "true"
```
Shows all roles including empty ones and exports the flattened report to CSV beside the script.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| ShowEmptyRoles | String | No | false | When `"true"`, shows roles with no current assignments |
| ExportToCsv | String | No | false | When `"true"`, exports the role assignments report to a CSV file |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Role assignments enumerated — results shown / exported |
| 1    | Script error (authentication, Graph RBAC, or principal resolution failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementRBAC.Read.All`, `User.Read.All`, `Group.Read.All` (delegated or application); sensitive RBAC export.

### Logging
* `C:\ProgramData\get-intune-role-assignments\Logs\`

---

# 🛡 Operational Notes

* **RBAC export sensitivity:** output resolves and exports Intune role membership (users, groups, scopes) — treat the CSV as sensitive and restrict distribution; use `-ShowEmptyRoles` only for completeness reviews.
* Per-assignment `$expand=roleDefinition` is fetched individually because the list endpoint does not link assignments to roles; throttled principal lookups retry once after 60s.
* Assignment dates may not be available for older assignments.
* **Backup depth 25 and Restore ShouldProcess (tenant governance):** RBAC data is not part of configuration backup; companion backup uses `ConvertTo-Json -Depth 25` and restore is gated by `SupportsShouldProcess` / `-WhatIf`.
* Beta Graph endpoints are used for RBAC surfaces; paging uses `Get-MgGraphAllPages` with `Retry-After` handling.

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
