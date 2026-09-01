<div align="center">

# 📱 Invoke Intune Bulk Actions

**Performs bulk Intune device actions: sync, restart, BitLocker key rotation, Windows Defender scan, and collect diagnostics.**

Executes a specified remote action against multiple Intune managed devices. Devices can be targeted by group membership, OS type, compliance state, or a CSV file of device names. Includes safety confirmations, throttling to avoid Graph API rate limits, and detailed progress/result tracking. Supported actions: Sync, Restart, BitLockerRotate, DefenderScan, DefenderSignatures, CollectDiagnostics.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke Intune Bulk Actions** is a PowerShell reporting script that executes a specified remote action against multiple Intune managed devices. Devices can be targeted by group membership, OS type, compliance state, or a CSV file of device names. Includes safety confirmations, throttling to avoid Graph API rate limits, and detailed progress/result tracking. Supported actions: Sync, Restart, BitLockerRotate, DefenderScan, DefenderSignatures, CollectDiagnostics.

It is part of the **Intune Device Operations** category and runs from a workstation — no agent deployment required. The script supports interactive sign-in (via `MgGraphCommunity` for WAM-free flow) and unattended app-only authentication via `-TenantId` / `-ClientId` with certificate or secret.

---

# ✨ Features

* Executes bulk remote actions (Sync, Restart, BitLocker rotation, Defender scan, diagnostics) with throttling and result tracking
* Targets devices by group, OS, compliance state, or CSV input with deduplication and filtering
* Respects Graph throttling with per-request delays and Retry-After backoff
* Supports safety confirmations and `-Force` bypass for automation
* Portal-safe parameter handling for Azure Automation compatibility

---

# 📂 Project Structure

```text
Invoke-IntuneBulkActions
│
├── Invoke-IntuneBulkActions.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Invoke-IntuneBulkActions.ps1
```

### Example 1
```powershell
.\Invoke-IntuneBulkActions.ps1 -Action Sync -GroupName "SG-Windows-Pilot"
```
 # Sync all devices in a group

### Example 2
```powershell
.\Invoke-IntuneBulkActions.ps1 -Action Sync -OSFilter "Windows" -StaleOnly -StaleDays 3
```
 # Sync Windows devices that haven't checked in for 3+ days

### Example 3
```powershell
.\Invoke-IntuneBulkActions.ps1 -Action Restart -DeviceNames "PC-001","PC-002" -Force
```
 # Restart specific devices without confirmation

### Example 4
```powershell
.\Invoke-IntuneBulkActions.ps1 -Action DefenderScan -NonCompliantOnly -OSFilter "Windows"
```
 # Trigger Defender scan on non-compliant Windows devices

### Example 5
```powershell
.\Invoke-IntuneBulkActions.ps1 -Action BitLockerRotate -CsvPath "C:\temp\devices.csv"
```
 # Rotate BitLocker keys for devices listed in a CSV


---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `OutputPath` | string | No | - | Output path |

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
* `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `Device.Read.All`, `Directory.Read.All`, `Group.Read.All`, `GroupMember.Read.All`

### Logging
* `C:\ProgramData\invoke-intunebulkactions\Logs\`

---

# 🛡 Operational Notes
* Test in a staging tenant first; Graph permission errors surface as 403 — check Entra ID consent for the listed scopes.
* Respect Graph throttling: the script includes built-in delays and 429 retry handling, but large tenants may still take several minutes.

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
