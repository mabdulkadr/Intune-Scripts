<div align="center">

# 🩺 Get Device Checkin Health

**Buckets devices by sync freshness to surface drifting fleets.**

Analyzes `lastSyncDateTime` to classify devices as Healthy, Drifting, Stale, or Never synced — highlights action window before unmanaged state.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Get Device Checkin Health** is a PowerShell script that retrieves all Intune managed devices and buckets them by how recently they checked in: Healthy (synced within `-HealthyDays`), Drifting (missed Healthy window but not yet Stale), Stale (beyond `-StaleDays`), and Never synced (no `lastSyncDateTime`). The Drifting bucket surfaces devices on their way to unmanaged state while intervention is still possible, with per-platform distribution and optional CSV export.

---

# ✨ Features

* Four buckets: **Healthy** (<= `-HealthyDays`), **Drifting** (Healthy-Stale window), **Stale** (> `-StaleDays`), **Never synced** (null `lastSyncDateTime`)
* Thresholds validated: `-HealthyDays` (1-90, default 7) must be smaller than `-StaleDays` (2-365, default 30)
* Per-platform distribution and compliance-state columns in export
* Complements stale-device reports by focusing on the actionable Drifting tail
* Beta Graph endpoints with throttling-aware pagination

---

# 📂 Project Structure

```text
Get-DeviceCheckinHealth
│
├── Get-DeviceCheckinHealth.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-DeviceCheckinHealth.ps1
```
Buckets devices as Healthy (7 days), Drifting (7-30 days), Stale (over 30 days), and Never synced.

### With Parameters
```powershell
.\Get-DeviceCheckinHealth.ps1 -HealthyDays 3 -StaleDays 21 -ExportToCsv "true"
```
Uses tighter thresholds (Healthy <=3d, Stale >21d) and exports the full device list with `DaysSinceSync`, `HealthBucket`, `OperatingSystem`, and `ComplianceState` to CSV.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| HealthyDays | Int | No | 7 | Days within which a device counts as healthy (1-90, must be < StaleDays) |
| StaleDays | Int | No | 30 | Days after which a device counts as stale (2-365, must be > HealthyDays) |
| ExportToCsv | String | No | false | When `"true"`, exports the full device list with health buckets to a timestamped CSV |
| OutputPath | String | No | "." | Output path for CSV exports (relative paths resolve beside the script) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Check-in health analyzed — buckets shown / exported |
| 1    | Script error (authentication, threshold validation, or Graph failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementManagedDevices.Read.All` (delegated or application); Intune Administrator.

### Logging
* `C:\ProgramData\get-device-checkin-health\Logs\`

---

# 🛡 Operational Notes

* **Drift thresholds:** `-HealthyDays` (1-90, default 7) must be smaller than `-StaleDays` (2-365, default 30); devices with no `lastSyncDateTime` are bucketed as **Never synced**; the **Drifting** bucket (7-30 days by default) is the actionable intervention window before stale.
* Export includes `DaysSinceSync`, `HealthBucket`, `OperatingSystem`, and `ComplianceState`; per-platform distribution is shown in console output.
* Complements plain stale-device reports — this script surfaces the degrading middle band, not just the tail.
* Beta Graph endpoints are used for consistency; paging handles `429` with 60s backoff; logs via `Initialize-Log` / `Write-Banner`.
* `-OutputPath` defaults to the script directory (Law 12); test threshold tuning in a staging tenant before production.

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
