<div align="center">

# 📊 Check Bit Locker Keys

**Monitor and verify that BitLocker recovery keys for Windows devices are properly stored in Entra ID.**

This script connects to Microsoft Graph API, retrieves all Windows devices from Intune, and checks if each device has BitLocker recovery keys stored in Entra ID. The script provides detailed reporting on compliance status, identifies devices without stored keys, and exports comprehensive results to CSV format for fu...

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.4.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check Bit Locker Keys** is a PowerShell reporting script that This script connects to Microsoft Graph API, retrieves all Windows devices from Intune, and checks if each device has BitLocker recovery keys stored in Entra ID. The script provides detailed reporting on compliance status, identifies devices without stored keys, and exports comprehensive results to CSV format for fu...

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
Test-BitLockerKeys
│
├── Test-BitLockerKeys.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Test-BitLockerKeys.ps1
```

### Example 1
```powershell
.\Test-BitLockerKeys.ps1
```
Generates BitLocker key storage report for all Windows devices in Intune

### Example 2
```powershell
.\Test-BitLockerKeys.ps1 -OutputPath "C:\Reports" -OnlyShowMissing "true"
```
Saves report to specified directory and shows only devices missing BitLocker keys

### Example 3
```powershell
.\Test-BitLockerKeys.ps1 -IncludeLastSync "true" -ExportJson "true"
```
Includes last sync information and exports results in JSON format as well

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `OutputPath` | string | No | - | Directory path to save reports |
| `OnlyShowMissing` | string | No | - | Only show devices missing BitLocker keys |
| `IncludeLastSync` | string | No | - | Include last sync date information |
| `ExportJson` | string | No | - | Export results in JSON format as well |
| `ShowProgress` | string | No | - | Show progress during processing |
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
* `DeviceManagementManagedDevices.Read.All`, `BitlockerKey.ReadBasic.All`

### Logging
* `C:\ProgramData\check-bitlocker-keys\Logs\`

---

# 🛡 Operational Notes
* Per-device key checks are paced at 100 ms with 429 retry and 60 s backoff; large estates (thousands of devices) will take several minutes — use `-OnlyShowMissing` and `-ShowProgress` to reduce noise.
* Test in a staging tenant first; Graph permission errors surface as 403 — check Entra ID consent for the listed scopes.

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
