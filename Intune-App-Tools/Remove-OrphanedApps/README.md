<div align="center">

# 🧩 Remove Orphaned Apps

**Finds Intune apps that have no assignments or are superseded by newer versions, and optionally deletes them.**

Scans the entire Intune app catalog for cleanup candidates — unassigned apps and superseded Win32 apps — and reports them by default, requiring an explicit switch and confirmation to delete, so administrators can prune abandoned test apps and old installer versions safely.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Remove-OrphanedApps** is a PowerShell script that identifies orphaned and superseded apps in the Intune app catalog and, when requested, removes them.

It pages all mobile apps with expanded assignments via Microsoft Graph beta, filters to candidates older than a cutoff (default 30 days), and classifies each as Unassigned, Superseded, or Unassigned + Superseded — using `supersedingAppCount` for Win32 supersedence. By default the script is report-only; deletion requires `-Remove "true"`, honors `-WhatIf` preview, and prompts per app via `ShouldProcess`. Deleting an Intune app does not uninstall it from devices that already have it, but it permanently removes the deployment object. Supports workstation dual-mode authentication: interactive sign-in (WAM-free via MgGraphCommunity) or app-only with tenant, client ID, and secret or certificate.

---

# ✨ Features

* Discovers unassigned apps with zero assignments and superseded Win32 apps via supersedence count
* Age filter via `-OlderThanDays` to avoid flagging work-in-progress deployments
* Report-only by default; deletion is opt-in and irreversible in the catalog
* `-WhatIf` preview showing exactly which apps would be deleted without deleting them
* Per-app confirmation through `SupportsShouldProcess` with high confirm impact
* Classified output by reason with CSV export and summary counts
* Throttling-aware Graph paging and structured timestamped logging

---

# 📂 Project Structure

```text
Remove-OrphanedApps
│
├── Remove-OrphanedApps.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Remove-OrphanedApps.ps1
```
Reports unassigned and superseded apps without deleting anything.

### Filter By Age
```powershell
.\Remove-OrphanedApps.ps1 -OlderThanDays 90
```
Only reports apps created more than 90 days ago.

### Preview Deletions
```powershell
.\Remove-OrphanedApps.ps1 -Remove "true" -WhatIf
```
Shows exactly which apps would be deleted without deleting them.

### Delete With Export
```powershell
.\Remove-OrphanedApps.ps1 -Remove "true" -ExportToCsv "true" -OutputPath "C:\Reports"
```
Deletes confirmed cleanup candidates and exports the report to a timestamped CSV file.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| OlderThanDays | Int | No | 30 | Only consider apps created more than this many days ago (0-3650) |
| Remove | String | No | "false" | Delete the reported apps instead of only reporting (true/false, 1/0) |
| ExportToCsv | String | No | "false" | Export results to a timestamped CSV file (true/false, 1/0) |
| OutputPath | String | No | "." | Output directory for CSV exports |
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
* Microsoft Graph: `DeviceManagementApps.ReadWrite.All`
* Entra role: **Intune Administrator**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed when missing; prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` (auto-installed when available for WAM-free interactive sign-in)

### Logging
* `C:\ProgramData\cleanup-orphaned-apps\Logs\`

---

# 🛡 Operational Notes

* **Destructive operation:** when run with `-Remove`, the script permanently deletes Intune deployment objects. Deleting an app does not uninstall it from devices that already have it, but the deletion is irreversible in the catalog.
* **Always preview first:** run report-only (default) or with `-Remove "true" -WhatIf` and review the grouped output before any real deletion.
* **Recently created apps are excluded by default** (`-OlderThanDays 30`) to avoid flagging work in progress; lower the value only when targeting specific recent test apps.
* Superseded means another Win32 app declares a supersedence relationship to the app (`supersedingAppCount` greater than 0); this property is only exposed on the beta endpoint.
* Deletion prompts per app via `ShouldProcess` — respond `A` to confirm all or run unattended only after a clean preview.
* Test against a staging tenant before running with `-Remove` in production and keep a CSV export for audit.

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
