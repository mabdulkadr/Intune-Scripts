<div align="center">

# 🧩 Get App Install Status

**Generates a comprehensive application installation status report for all managed applications in Intune.**

Retrieves every managed app and its per-device install state via the deviceManagement reports endpoint, producing CSV and HTML reports with success, failure, and pending breakdowns — built for Intune administrators troubleshooting deployments.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get-AppInstallStatus** is a PowerShell script that builds a fleet-wide application installation status report from Microsoft Intune.

It authenticates to Microsoft Graph, enumerates mobile apps with selectable filters, and pulls per-device install status rows (installed, failed, pending, not applicable, and related states) through the `deviceManagement/reports/retrieveDeviceAppInstallationStatusReport` beta endpoint — preserving single-row results and handling paged app enumeration. Results are aggregated into summary statistics (success and failure rates, top failed apps, status by platform) and exported as timestamped CSV and styled HTML. Supports workstation dual-mode: interactive sign-in (WAM-free via MgGraphCommunity) or app-only with tenant, client ID, and secret or certificate.

---

# ✨ Features

* Per-device install state reporting via the reports endpoint (installed, failed, pendingInstall, notInstalled, and more)
* Platform and install-state filtering with wildcard matching (e.g., pending matches pendingInstall)
* CSV and styled HTML exports with success-rate progress bar and platform breakdown
* Throttling-aware paging with Retry-After honor and per-app retry logic
* Top failed applications and status-by-platform aggregations
* Workstation dual-mode authentication and structured timestamped logging
* Handles large tenants with paged downloads and rate-limit delays

---

# 📂 Project Structure

```text
Get-AppInstallStatus
│
├── Get-AppInstallStatus.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-AppInstallStatus.ps1
```
Generates an application installation status report for all applications.

### Filter By Install State
```powershell
.\Get-AppInstallStatus.ps1 -FilterByInstallState "failed"
```
Generates a report showing only failed application installations.

### Filter By Platform And Output Path
```powershell
.\Get-AppInstallStatus.ps1 -FilterByPlatform "Windows" -OutputPath "C:\Reports"
```
Generates a report for Windows applications and saves to the specified directory.

### Filter By App Name And Open Report
```powershell
.\Get-AppInstallStatus.ps1 -FilterByAppName "Microsoft 365" -OpenReport "true"
```
Generates a report filtered by application name and opens the HTML report automatically.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| OutputPath | String | No | "." | Output directory for CSV and HTML reports |
| FilterByInstallState | String | No | "all" | Filter by install state: all, installed, failed, pending, notApplicable, error |
| FilterByPlatform | String | No | "all" | Filter by platform: all, Windows, iOS, Android, macOS |
| FilterByAppName | String | No | "" | Filter applications by display name (wildcard) |
| OpenReport | String | No | "false" | Open the generated HTML report automatically (true/false, 1/0) |
| MaxApps | Int | No | 0 | Maximum number of apps to process (0 = all) |
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
* Microsoft Graph: `DeviceManagementApps.Read.All`, `DeviceManagementManagedDevices.Read.All`
* Entra role: **Intune Administrator**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed when missing; prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` (auto-installed when available for WAM-free interactive sign-in)

### Logging
* `C:\ProgramData\get-app-installation-status-report\Logs\`

---

# 🛡 Operational Notes

* Read-only reporting — creates no tenant objects and performs no device actions.
* Large tenants may take considerable time due to API rate limits; throttling pauses are automatic and honor Retry-After where exposed.
* Reports are saved in both CSV and HTML formats in the directory specified by `-OutputPath`.
* Uses the beta endpoint for comprehensive installation status data; the older mobileApps deviceStatuses endpoint is retired.
* Report auto-open failures do not abort the script; warnings are emitted instead.

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
