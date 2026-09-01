<div align="center">

# 🩺 Get Enrollment Failure Report

**Reports enrollment and Autopilot failures with plain-language explanations.**

Reads `troubleshootingEvents` and `autopilotEvents` to group failures by category and translate codes into fixes — no portal click-through.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get Enrollment Failure Report** is a PowerShell script that retrieves enrollment troubleshooting events and Windows Autopilot deployment events from Microsoft Graph, groups failures by `failureCategory`, and translates each category into plain-language explanations with typical fixes. It resolves `userId -> userPrincipalName` where possible and filters to the `-DaysBack` window (retention-limited).

---

# ✨ Features

* Reads `deviceManagement/troubleshootingEvents` (enrollment) and optionally `deviceManagement/autopilotEvents` (`-IncludeAutopilotEvents`)
* Groups failures by `failureCategory` with plain-language explanations (e.g., `enrollmentRestrictionsEnforced`, `authorization`, `authentication`) and typical fixes
* Resolves `userId -> userPrincipalName` and shows `deploymentState` / `enrollmentState` per serial for Autopilot
* Retention-aware filtering: `eventDateTime ge <cutoff>` where cutoff is `Now - DaysBack` (1-180, default 30)
* Optional CSV export (timestamped beside script) and beta Graph pagination with 60s backoff on 429

---

# 📂 Project Structure

```text
Get-EnrollmentFailureReport
│
├── Get-EnrollmentFailureReport.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-EnrollmentFailureReport.ps1
```
Reports enrollment failures from the last 30 days grouped by failure category.

### With Parameters
```powershell
.\Get-EnrollmentFailureReport.ps1 -DaysBack 7 -IncludeAutopilotEvents "true" -ExportToCsv "true"
```
Reports the last 7 days including Autopilot deployment events (`deploymentState` per serial) and exports to CSV.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| DaysBack | Int | No | 30 | How many days back to report (1-180) |
| IncludeAutopilotEvents | String | No | false | When `"true"`, also includes Windows Autopilot deployment events |
| ExportToCsv | String | No | false | When `"true"`, exports results to a timestamped CSV file |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Enrollment failures reported — categories shown / exported |
| 1    | Script error (authentication, Graph troubleshooting/autopilot query failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementManagedDevices.Read.All`, `DeviceManagementServiceConfig.Read.All`, `User.Read.All` (delegated or application); Intune Administrator.

### Logging
* `C:\ProgramData\get-enrollment-failure-report\Logs\`

---

# 🛡 Operational Notes

* **Retention / timeout:** troubleshooting events are retained by Intune for a limited period — older failures may no longer be available; the script filters with `eventDateTime ge <cutoff>` where cutoff is `Now - DaysBack` (1-180, default 30).
* **Autopilot drift:** add `-IncludeAutopilotEvents "true"` to also list `autopilotEvents` within the same window, showing `deploymentState` / `enrollmentState` per serial; outputs are grouped by `failureCategory` with explanations.
* User principal names are resolved from `userId` on the event whenever possible; missing users show as ID.
* Beta Graph endpoints are used for troubleshooting and Autopilot events; paging handles `429` with 60s backoff.
* `-OutputPath` defaults to the script directory (Law 12); logs via `Initialize-Log` / `Write-Banner`; test in staging before production.

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
