<div align="center">

# 🧩 Get App Assignment Conflicts

**Detects conflicting Intune app assignments: required versus uninstall, and groups that are both included and excluded.**

Analyzes every Intune app's assignments and reports hard-to-spot conflicts — required and uninstall on the same app, the same group both included and excluded, and the same group with mixed intents — resolving group display names so the report is directly actionable for Intune administrators.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get-AppAssignmentConflicts** is a PowerShell script that detects assignment conflicts across the Intune app catalog.

It pages every mobile app with expanded assignments via the Microsoft Graph beta endpoint, builds per-target include and exclude views, and surfaces three conflict types: an app deployed as both required and uninstall, the same group both included and excluded on one app, and the same group receiving the same app with multiple different intents. Group IDs are resolved to display names with caching so the output is actionable without portal cross-referencing. Supports interactive sign-in (WAM-free via MgGraphCommunity when available) and app-only authentication.

---

# ✨ Features

* Detects required versus uninstall intent on the same app
* Flags groups that are both included and excluded on a single app
* Detects mixed intents for the same target group with severity separation
* Resolves Azure AD group display names with in-memory caching
* Beta Graph assignment surface with throttling-aware paging
* Optional timestamped CSV export and workstation dual-mode authentication
* Structured timestamped logging mirrored to disk

---

# 📂 Project Structure

```text
Get-AppAssignmentConflicts
│
├── Get-AppAssignmentConflicts.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-AppAssignmentConflicts.ps1
```
Reports all app assignment conflicts in the console.

### Export To CSV
```powershell
.\Get-AppAssignmentConflicts.ps1 -ExportToCsv "true"
```
Exports the conflict report to a timestamped CSV file in the output path.

### Custom Output Path
```powershell
.\Get-AppAssignmentConflicts.ps1 -ExportToCsv "true" -OutputPath "C:\Reports"
```
Writes the CSV report to a specific directory.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
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
* Microsoft Graph: `DeviceManagementApps.Read.All`, `Group.Read.All`
* Entra role: **Intune Administrator**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed when missing; prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` (auto-installed when available for WAM-free interactive sign-in)

### Logging
* `C:\ProgramData\get-app-assignment-conflicts\Logs\`

---

# 🛡 Operational Notes

* Read-only reporting — creates no tenant objects and makes no assignments.
* Required + available for the same group is reported as informational, not a conflict (required wins by design).
* Nested group membership is not evaluated; only direct assignment targets are compared.
* Uses beta Graph endpoints for the app assignment surface; honors HTTP 429 with 60-second backoff.
* Group name resolution is best-effort; unresolved IDs fall back to the raw group ID.

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
