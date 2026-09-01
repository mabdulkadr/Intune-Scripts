<div align="center">

# 🧩 Intune App Tools

**App lifecycle reporting, hygiene, and deployment automation for Microsoft Intune.**

Inventory, assignment health, install status, duplicate detection, license tracking, orphan cleanup, and Winget-to-Win32 deployment — plus a local Company Portal repair tool.

[![Intune](https://img.shields.io/badge/Intune-App%20Tools-10B981?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [Operational Notes](#-operational-notes) • [License](#-license)

</div>

---

# 📖 Overview

**Intune App Tools** is the app-lifecycle category for Microsoft Intune — six Graph-powered reporting and hygiene scripts plus two standalone deployment and repair tools.

The reporting scripts surface fleet-wide application inventory, per-device install status, assignment conflicts, duplicate catalog entries, and Apple VPP license utilization entirely from Microsoft Graph. The hygiene script reports and optionally removes orphaned and superseded apps. The flagship **Invoke-Win32AppAutoDeployer** builds Entra groups, IntuneWin packages, Win32 apps, and auto-update remediations end-to-end from Winget. **Repair-CompanyPortal** is a purely local repair that cleanly reinstalls Company Portal via winget. Every Graph tool runs from an admin workstation in interactive or app-only mode; nothing in this category is deployed to endpoints by Intune itself except the artifacts AutoDeployer creates.

---

# ✨ Core Features

### 🔹 Fleet-Wide App Reporting
* Application inventory across all managed devices (CSV + HTML) with publisher/platform/size enrichment
* Installation status via the `deviceManagement/reports` endpoint with success/failure/pending breakdowns
* Assignment conflict detection — required vs. uninstall, include vs. exclude, and mixed intents per group

### 🔹 Catalog Hygiene
* Duplicate detection by normalized name, publisher, and app type
* Orphan and superseded app discovery with preview, `WhatIf`, and per-app confirmation before deletion
* VPP license utilization and token-expiry tracking for Apple Apps and Books

### 🔹 Deployment & Repair
* Winget-to-Win32 end-to-end automation — groups, scripts, IntuneWin packaging, upload, and assignment
* Proactive Remediation auto-update enforcement for deployed Win32 apps
* Local Company Portal uninstall → fresh install from the Microsoft Store source with elevation guard

### 🔹 Enterprise-Ready Execution
* Workstation dual-mode: interactive sign-in (WAM-free via MgGraphCommunity when available) or app-only with `-TenantId`/`-ClientId` + secret/certificate
* Structured, timestamped logging mirrored to `C:\ProgramData\<tool>\Logs`
* Throttling-aware pagination and retry handling across all Graph calls

---

# 📂 Project Structure

```text
Intune-App-Tools
│
├── Get-AppAssignmentConflicts.ps1
├── Get-AppInstallStatus.ps1
├── Get-ApplicationInventory.ps1
├── Get-DuplicateApplications.ps1
├── Get-VppLicenseReport.ps1
├── Remove-OrphanedApps.ps1
├── Repair-CompanyPortal/
│   └── Repair-CompanyPortal.ps1
├── Invoke-Win32AppAutoDeployer/
│   └── Invoke-Win32AppAutoDeployer.ps1
└── README.md
```

---

# 📜 Scripts Included

| Script | Purpose | Graph Permissions | Run Context |
| ------ | ------- | ----------------- | ----------- |
| `Get-ApplicationInventory.ps1` | Generates a fleet-wide application inventory from managed devices (CSV + HTML) with filtering by publisher, app name, and system-app inclusion. | `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only |
| `Get-AppInstallStatus.ps1` | Reports per-device application installation status (installed, failed, pending, not applicable) via the `deviceManagement/reports` endpoint with CSV + HTML output and platform/state filters. | `DeviceManagementApps.Read.All`, `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only |
| `Get-AppAssignmentConflicts.ps1` | Detects conflicting assignments: required vs. uninstall on the same app, same group both included and excluded, and same group with mixed intents; resolves group display names. | `DeviceManagementApps.Read.All`, `Group.Read.All` | Workstation — interactive or app-only |
| `Get-DuplicateApplications.ps1` | Finds duplicate apps in the Intune catalog by normalized name — same name with different publishers, name variations, or different app types — and exports CSV + HTML. | `DeviceManagementApps.Read.All` | Workstation — interactive or app-only |
| `Get-VppLicenseReport.ps1` | Reports Apple VPP (iOS/macOS) license utilization (used vs. total) and flags apps above a utilization threshold plus VPP tokens nearing expiry or in an invalid state. | `DeviceManagementApps.Read.All` | Workstation — interactive or app-only |
| `Remove-OrphanedApps.ps1` | Scans the app catalog for cleanup candidates — apps with no assignments and Win32 apps superseded by a newer app — and optionally deletes them with `-Remove`/`-WhatIf` and per-app confirmation. | `DeviceManagementApps.ReadWrite.All` | Workstation — interactive or app-only |
| `Invoke-Win32AppAutoDeployer/Invoke-Win32AppAutoDeployer.ps1` | Flagship Winget-to-Win32 pipeline: interactive or unattended selection, Entra Install/Uninstall group creation, script generation, IntuneWin packaging, upload as Win32 LOB app, Proactive Remediation for auto-updates, and assignment. | `DeviceManagementApps.ReadWrite.All`, `DeviceManagementConfiguration.ReadWrite.All`, `Group.ReadWrite.All`, `GroupMember.ReadWrite.All` (interactive); `DeviceManagementApps.ReadWrite.All` + `DeviceManagementConfiguration.ReadWrite.All` + `Group.ReadWrite.All` (app-only) | Workstation — interactive GridView or unattended app-only |
| `Repair-CompanyPortal/Repair-CompanyPortal.ps1` | Repairs Company Portal locally: verifies elevation, resolves winget from the App Installer package, uninstalls the existing Portal when present, and reinstalls it fresh from the `msstore` source. | None — local execution only | Local workstation — elevated Administrator console, no Graph calls |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** — the Invoke-Win32AppAutoDeployer auto-relaunches under 5.1 when invoked from PowerShell 7

### Modules
* `Microsoft.Graph.Authentication` — required for every script except `Repair-CompanyPortal.ps1`; auto-installed when missing (prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` — auto-installed when available to provide WAM-free interactive sign-in on Windows
* `Repair-CompanyPortal` has no Graph dependency; it requires the App Installer (winget) package

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

### Permissions
* Least-privilege scopes per script are listed in the table above; consent the union for batch runs
* Entra role: **Intune Administrator** for reporting/hygiene scripts; **Intune Service Administrator** (or equivalent) for Invoke-Win32AppAutoDeployer
* `Repair-CompanyPortal` requires an elevated (Administrator) console only

### Logging
* Graph tools: `C:\ProgramData\<SolutionName>\Logs\` — e.g. `C:\ProgramData\get-application-inventory-report\Logs\`, `C:\ProgramData\cleanup-orphaned-apps\Logs\`
* Invoke-Win32AppAutoDeployer: `C:\ProgramData\Invoke-Win32AppAutoDeployer\Logs\`
* Repair-CompanyPortal: `C:\ProgramData\Repair-CompanyPortal\Logs\`
* Working files for Invoke-Win32AppAutoDeployer are staged under `C:\Temp\<random>-<timestamp>\`

---

# 🛡 Operational Notes

* **Destructive — orphan removal:** `Remove-OrphanedApps.ps1` deletes Intune deployment objects when run with `-Remove`. Deleting an app does not uninstall it from devices, but it is irreversible in the catalog. Always preview first (default report-only, or `-Remove "true" -WhatIf`) and test against a staging tenant.
* **Mutates the tenant — AutoDeployer:** `Invoke-Win32AppAutoDeployer.ps1` creates Entra security groups, Win32 LOB apps, assignments, and Proactive Remediations. Never run against production without testing. Staging group names under `C:\Temp\<random>-<timestamp>\` are cleaned periodically after large batches.
* **Read-only by default:** All other scripts are reporting-only and create no tenant objects.
* **Throttling:** Every Graph tool pages with `Get-MgGraphAllPages` and retries on HTTP 429/503 (honoring `Retry-After` where exposed). Large tenants will pause automatically; do not abort on the first throttling message.
* **Local-only repair:** `Repair-CompanyPortal` modifies the local device (removes and reinstalls the Company Portal package) and never contacts Graph. It requires elevation and the `msstore` source.
* **Interactive vs. unattended:** Leave `-TenantId`/`-ClientId` unset for interactive delegated sign-in; supply them plus `-ClientSecret` or `-CertificateThumbprint` for unattended app-only runs.

> **Attribution:** Adapted in part from github.com/ugurkocde/IntuneAutomation (Ugur Koc, MIT) — see THIRD-PARTY-NOTICES.md.

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
