<div align="center">

# 📊 Export Intune Audit Logs

**Retrieves and displays audit log entries from Microsoft Intune with filtering and export options.**

This script connects to Microsoft Graph to retrieve audit log entries from Intune, showing administrative actions, configuration changes, and other tracked activities. It provides detailed information about who performed actions, what was changed, when it occurred, and the result. Supports filtering by date range, u...

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Export Intune Audit Logs** is a PowerShell reporting script that This script connects to Microsoft Graph to retrieve audit log entries from Intune, showing administrative actions, configuration changes, and other tracked activities. It provides detailed information about who performed actions, what was changed, when it occurred, and the result. Supports filtering by date range, u...

It is part of the **Intune Reporting Tools** category and runs from a workstation — no agent deployment required. The script supports interactive sign-in (via `MgGraphCommunity` for WAM-free flow) and unattended app-only authentication via `-TenantId` / `-ClientId` with certificate or secret.

---

# ✨ Features

* Queries Microsoft Graph (beta) with automatic pagination and 429/503 retry handling
* Exports structured CSV for Excel/Power BI and an interactive HTML summary
* Respects Graph throttling with per-request delays and Retry-After backoff
* Supports interactive sign-in (MgGraphCommunity, WAM-free) and unattended app-only auth (`TenantId`/`ClientId` + secret/cert)
* Portal-safe boolean parameters (`"true"/"false"/"1"/"0"`) for Azure Automation compatibility

---

# 📂 Project Structure

```text
Export-IntuneAuditLogs
│
├── Export-IntuneAuditLogs.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Export-IntuneAuditLogs.ps1
```

### Example 1
```powershell
.\Export-IntuneAuditLogs.ps1
```
Displays the last 20 audit log entries

### Example 2
```powershell
.\Export-IntuneAuditLogs.ps1 -NumberOfEntries 50 -DaysBack 7
```
Shows the last 50 audit entries from the past 7 days

### Example 3
```powershell
.\Export-IntuneAuditLogs.ps1 -FilterByUser "<recipient-address>" -ExportToCsv "true"
```
Shows all audit entries for a specific user and exports to CSV

### Example 4
```powershell
.\Export-IntuneAuditLogs.ps1 -FilterByActivity "*Policy*" -ExportToHtml "true" -OpenReport "true"
```
Shows audit entries related to policy changes and opens HTML report


---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `NumberOfEntries` | int | No | - | Number of audit entries to retrieve |
| `DaysBack` | int | No | - | Number of days back to search |
| `FilterByUser` | string | No | - | Filter by user (supports wildcards) |
| `FilterByActivity` | string | No | - | Filter by activity name (supports wildcards) |
| `FilterByCategory` | string | No | - | Filter by category |
| `OnlyFailures` | string | No | - | Show only failed operations |
| `ExportToCsv` | string | No | - | Export results to CSV |
| `ExportToHtml` | string | No | - | Export results to HTML |
| `OutputPath` | string | No | - | Output path for exports |
| `OpenReport` | string | No | - | Open HTML report after generation |
| `DetailedView` | string | No | - | Show detailed properties for each entry |
| `ForceModuleInstall` | string | No | - | Force module installation without prompting |
| `TenantId` | string | No | - | Tenant ID for app-only authentication |
| `ClientId` | string | No | - | Client ID for app-only authentication |
| `ClientSecret` | string | No | - | Client secret for app-only authentication |
| `CertificateThumbprint` | string | No | - | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success |
| 1 | Failure |


---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementApps.Read.All`, `DeviceManagementConfiguration.Read.All`, `DeviceManagementManagedDevices.Read.All`

### Logging
* `C:\ProgramData\get-intune-audit-logs\Logs\`

---

# 🛡 Operational Notes
* Intune audit events (`deviceManagement/auditEvents`) are retained for **30 days**; older changes must be archived externally.
* Test in a staging tenant first; Graph permission errors surface as 403 — check Entra ID consent for the listed scopes.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

**Mohammad Abdelkader Omar** (maintainer) — original author: **Ugur Koc**

Adapted in part from github.com/ugurkocde/IntuneAutomation (Ugur Koc, MIT) — see THIRD-PARTY-NOTICES.md.
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
