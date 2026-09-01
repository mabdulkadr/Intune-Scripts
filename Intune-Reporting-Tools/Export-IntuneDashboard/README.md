<div align="center">

# 📊 Export-IntuneDashboard

**Single-page integrated tenant health report (Intune + Entra ID + 365).**

Pulls data from 17 Microsoft Graph endpoints in one pass and renders a self-contained HTML report with 12 KPI tiles, 4 donut charts, 2 bar charts, and 8 detail tables — covering compliance, security, inventory, licensing, service health, connectors, and Windows 365. The 2.0 release merges the former Get-DailyTenantReport into this single integrated dashboard.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Export-IntuneDashboard** is the consolidated tenant health report for Intune, Entra ID, and Windows 365. It replaces both the original dashboard script and `Get-DailyTenantReport.ps1` (now removed) with a single integrated report that covers everything operators need in one page.

The 2.0 release adds 6 new KPI tiles, 8 new detail sections, and 4 new Graph endpoint categories — all rendered in the same Carbon-themed dark HTML report. Output is a self-contained HTML file with zero external dependencies: open it in any browser, share it with your team, or print to PDF.

---

# ✨ Features

* **12 KPI tiles** — Managed Devices, Compliance, Stale, Risky Users, CA Policies, Not Encrypted, M365 Secure Score, Intune Service Health, Apple Certs (soonest), Failed Sign-ins (24h), Cloud PCs (365), Connectors
* **Compliance & Device Overview** — Compliance donut with grade card, OS distribution bar chart
* **Encryption & Sync Health** — Encryption donut with %, Sync Health donut (active/warn/stale)
* **License utilisation** table with progress bars sorted by usage %
* **M365 Secure Score** gauge with posture color (Strong/Moderate/Weak)
* **Apple Certificates & Tokens** — APNs, VPP, DEP expiry with severity badges (red < 30d, yellow < 90d)
* **Intune Service Health** — operational status + active issues
* **Tenant Connectors** — MTD, NDES, ServiceNow, Zebra FOTA, Remote Assist, Compliance Partner with heartbeat monitoring
* **Windows Update Reports** — feature/quality/driver alerts summary
* **Identity & Application Security** — Failed Entra sign-ins (24h) + Expiring app registrations (90d)
* **Windows 365 Cloud PCs** — total, provisioned, failed
* **Self-contained HTML** with donut charts, bar charts, severity badges, and print-optimized CSS
* **Footer with** Print, Copy Path, Top, Disclaimer modal, Text Summary export
* **Graph pagination** via `Get-MgGraphAllPages` with structured logging to `C:\ProgramData\Export-IntuneDashboard\Logs\`

---

# 📂 Project Structure

```text
Export-IntuneDashboard
│
├── Export-IntuneDashboard.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Export-IntuneDashboard.ps1
```

### Example 1
```powershell
.\Export-IntuneDashboard.ps1
```
Generates the dashboard using default output beside the script.

### Example 2
```powershell
.\Export-IntuneDashboard.ps1 -OutputPath "C:\Reports\Dashboard.html"
```
Generates the dashboard at a specific path.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `OutputPath` | String | No | Beside script | Where to save the HTML file. Defaults to beside the script. |
| `DaysStale` | Int32 | No | 90 | Days before a device is considered stale. |

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
* `DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All, DeviceManagementServiceConfig.Read.All, DeviceManagementApps.Read.All, Device.Read.All, Directory.Read.All, Group.Read.All, User.Read.All, Policy.Read.All, Application.Read.All, AuditLog.Read.All, IdentityRiskyUser.Read.All, Organization.Read.All, RoleManagement.Read.All`

### Logging
* `C:\ProgramData\Export-IntuneDashboard\Logs\`

---

# 🛡 Operational Notes
* Read-only Graph queries; never modifies tenant or device state.
* Missing Graph data renders as empty sections; never aborts the report.
* Test with `Get-MgContext` first; 403 errors indicate missing consent for the listed scopes.

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