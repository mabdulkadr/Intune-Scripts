<div align="center">

# 🔒 Rotate BitLocker Keys

**Rotates BitLocker keys for all Windows devices in Intune using Graph API.**

This script connects to Intune via Graph API and rotates the BitLocker keys for all managed Windows devices.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Rotate BitLocker Keys** is a PowerShell script that This script connects to Intune via Graph API and rotates the BitLocker keys for all managed Windows devices. The script retrieves all Windows devices from Intune and triggers BitLocker key rotation for each device. It provides real-time feedback on the rotation process and handles errors gracefully. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

This script connects to Intune via Graph API and rotates the BitLocker keys for all managed Windows devices. The script retrieves all Windows devices from Intune and triggers BitLocker key rotation for each device. It provides real-time feedback on the rotation process and handles errors gracefully. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Rotates BitLocker recovery keys tenant-wide via Graph `rotateBitLockerKeys`
* Targets all Windows devices with `-DryRun "true"` preview and `-Force "true"` unattended skip
* Throttled with one automatic retry after 60s on 429
* Workstation LocalOnly — interactive or app-only
* Per-device result logging with summary and export

---

# 📂 Project Structure

```text
Rotate-BitLockerRecoveryKeys
│
├── Rotate-BitLockerRecoveryKeys.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\rotate-bitlocker-keys.ps1
```
Rotates BitLocker keys for all Windows devices in Intune

### Example 2
```powershell
.\rotate-bitlocker-keys.ps1 -DelaySeconds 5
```
Rotates BitLocker keys with a 5-second delay between operations

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DelaySeconds` | Int | No | `1` | Seconds between rotate calls (throttling) |
| `DryRun` | String | No | `false` | Preview targets (`"true"`) |
| `Force` | String | No | `false` | Skip confirmation (`"true"`) |
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
* `Microsoft.Graph.Authentication` (auto-installed if missing; `MgGraphCommunity >= 1.4.0` for WAM-free interactive sign-in)

### Permissions
* `DeviceManagementManagedDevices.ReadWrite.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\rotate-bitlocker-keys\Logs`

---

# 🛡️ Operational Notes

* All Security Tools run **LocalOnly** from an admin workstation via Microsoft Graph — interactive delegated (WAM-free via `MgGraphCommunity`) or app-only (`-TenantId`/`-ClientId`/`-ClientSecret` or `-CertificateThumbprint`) — with no Azure Automation dependency.
* Per-script least-privilege Graph permissions; consent on first interactive sign-in or pre-consent via Entra Enterprise Applications.
* Beta Graph endpoints where the surface requires it; paging with 429 throttling and one retry after 60s.
* Test in a staging tenant/device group before production; all scripts disconnect (`Disconnect-MgGraph` / `Disconnect-MgGraphCommunity`) and write structured logs.

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
