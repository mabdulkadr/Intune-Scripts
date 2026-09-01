<div align="center">

# 🔒 Get Windows LAPS Audit

**Audits Windows LAPS password escrow: which devices have a backed-up local admin password and how old it is.**

This script lists all device local credential records escrowed by Windows LAPS in
    Entra ID and cross-references them with Intune Windows devices.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.3.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Windows LAPS Audit** is a PowerShell script that This script lists all device local credential records escrowed by Windows LAPS in Entra ID and cross-references them with Intune Windows devices. It reports which devices have no escrowed local administrator password at all, and which have passwords older than the rotation threshold - both signs that the LAPS policy is not applying. Only credential metadata (device name, backup time) is read; actual passwords are never retrieved by this script. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

This script lists all device local credential records escrowed by Windows LAPS in Entra ID and cross-references them with Intune Windows devices. It reports which devices have no escrowed local administrator password at all, and which have passwords older than the rotation threshold - both signs that the LAPS policy is not applying. Only credential metadata (device name, backup time) is read; actual passwords are never retrieved by this script. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency. It runs **locally with no Graph calls** and writes structured logs for every operation.

---

# ✨ Features

* Audits Windows LAPS escrow: which devices have backed-up local admin password and how stale
* Cross-references Entra `deviceLocalCredentials` against Intune Windows devices via `azureADDeviceId`
* Detects no-escrow, stale (`-MaxPasswordAgeDays` default 60), and `EscrowedNoTimestamp` devices
* Status buckets: `Healthy` / `Stale` / `NotEscrowed` / `EscrowedNoTimestamp`
* Never retrieves password values — metadata only

---

# 📂 Project Structure

```text
Get-WindowsLapsAudit
│
├── Get-WindowsLapsAudit.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\get-windows-laps-audit.ps1
```
Audits LAPS escrow state for all Windows devices with a 60-day age threshold

### Example 2
```powershell
.\get-windows-laps-audit.ps1 -MaxPasswordAgeDays 30 -ExportToCsv "true"
```
Flags passwords older than 30 days and exports the audit to CSV

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `MaxPasswordAgeDays` | Int | No | `60` | Days after which escrow is flagged stale |
| `ExportToCsv` | String | No | `false` | Export audit to timestamped CSV (`"true"`) |
| `TenantId` / `ClientId` / `ClientSecret` / `CertificateThumbprint` | String | No | `` | App-only auth |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure (validation or Graph error) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Modules
* No Graph modules required — local execution only.

### Permissions
* Run from an **elevated** console — local administrator rights required. No Graph permissions required; inspects services, registry, and network state locally.

### Logging
* `C:\ProgramData\get-windows-laps-audit\Logs`

---

# 🛡️ Operational Notes

* **Windows LAPS audit — `azureADDeviceId` cross-reference:** `Get-WindowsLapsAudit.ps1` indexes Entra `deviceLocalCredentials` by `id` (which is the Entra device ID) and joins to Intune `managedDevices` via `azureADDeviceId`. Devices without escrow, stale passwords (`-MaxPasswordAgeDays`, default 60), and `EscrowedNoTimestamp` are reported separately. Status buckets: `Healthy` / `Stale` / `NotEscrowed` / `EscrowedNoTimestamp`. Never retrieves password values.
* Requires `DeviceLocalCredential.ReadBasic.All` + `DeviceManagementManagedDevices.Read.All` delegated or application permissions; Intune Administrator or equivalent role for metadata.
* Cross-tenant mismatches are flagged when Entra device IDs have no matching Intune record.

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
