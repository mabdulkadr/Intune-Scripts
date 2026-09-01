<div align="center">

# 🩺 Collect Device Diagnostics

**Triggers Intune remote diagnostics collection and downloads diagnostic ZIPs.**

Starts `Collect diagnostics` on Windows devices by name or Entra group, polls to completion, and downloads ZIP packages — built for troubleshooting at scale.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Collect Device Diagnostics** is a PowerShell script that starts the Intune `Collect diagnostics` remote action on one or more Windows devices (by `-DeviceNames` or `-GroupName`), waits for the collection to complete, and downloads the resulting diagnostic ZIP packages to a local folder; with `-DownloadExisting` it lists previous completed requests and fetches the newest package without triggering a new collection.

---

# ✨ Features

* Targets Windows 10/11 devices only — non-Windows devices are skipped with a warning
* Two modes: trigger new collection (`createDeviceLogCollectionRequest` with `templateType = predefined`) and `DownloadExisting` mode (`createDownloadUrl` for pre-authenticated Azure Storage link)
* Polls every 30s until `completed`/`failed` or `-TimeoutMinutes` (default 15, max 120); timed-out devices remain pending and can be fetched later with `-DownloadExisting`
* Group targeting resolves Entra group `members` -> `deviceId` -> Intune `azureADDeviceId` with full pagination
* Beta Graph endpoints with `Get-MgGraphAllPages` and `429` backoff (60s); structured logging

---

# 📂 Project Structure

```text
Collect-DeviceDiagnostics
│
├── Collect-DeviceDiagnostics.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Collect-DeviceDiagnostics.ps1 -DeviceNames "PC-001","PC-002"
```
Triggers diagnostics collection on two devices and downloads packages when ready (interactive sign-in, default 15-minute timeout).

### With Parameters
```powershell
.\Collect-DeviceDiagnostics.ps1 -GroupName "Support - Troubleshooting" -OutputPath "C:\DeviceLogs" -TimeoutMinutes 30
```
Collects diagnostics from all Windows devices in the group and saves ZIPs to `C:\DeviceLogs`; use `-DownloadExisting "true"` on the next run to fetch completed packages if some devices were offline.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| DeviceNames | String[] | No | None | Device names to collect diagnostics from (exactly one of DeviceNames or GroupName) |
| GroupName | String | No | None | Entra ID group whose Windows devices get diagnostics collected |
| OutputPath | String | No | "." | Folder in which diagnostic ZIP packages are saved (relative paths resolve beside the script) |
| DownloadExisting | String | No | false | When `"true"`, downloads the latest existing completed package instead of triggering a new collection |
| TimeoutMinutes | Int | No | 15 | Minutes to wait for collections to complete (1-120) |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Diagnostics collection triggered / downloaded — ZIPs saved to OutputPath |
| 1    | Script error (authentication, Graph log-collection failure, or download error) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementManagedDevices.ReadWrite.All` (listing and creating log collection requests requires ReadWrite — read-only scopes are rejected) + `GroupMember.Read.All` for group targeting.

### Logging
* `C:\ProgramData\collect-device-diagnostics\Logs\`

---

# 🛡 Operational Notes

* **Targeting:** specify exactly one target — `-DeviceNames` **or** `-GroupName`; group members are resolved via Entra `members` -> `deviceId` -> Intune `azureADDeviceId`; non-Windows devices are skipped.
* **Modes:** without `-DownloadExisting` the script POSTs `createDeviceLogCollectionRequest` per device (`templateType = predefined`) and polls every 30s; with `-DownloadExisting` it lists `logCollectionRequests`, picks the newest `completed` (`receivedDateTimeUTC` / `requestedDateTimeUTC`), and calls `createDownloadUrl` — the URL is a pre-authenticated Azure Storage link fetched via `Invoke-WebRequest`, not `Invoke-MgGraphRequest`.
* **Timeout / drift thresholds:** `-TimeoutMinutes` defaults to 15 (max 120); devices that do not complete within the timeout remain in `pendingRequests` and are reported as failures/timeouts — re-run later with `-DownloadExisting` to fetch the package once the device comes online.
* Beta Graph endpoints are used for the log collection surface; paging handles `429` with 60s backoff; logs are written via `Initialize-Log` / `Write-Banner` / `Write-Log`.
* `-OutputPath` defaults to the script directory (Law 12); test in a staging group before production.

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
