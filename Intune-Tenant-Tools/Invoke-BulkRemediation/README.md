<div align="center">

# 💻 Bulk Run Remediations On Demand

**Bulk Run Remediations On Demand**

Triggers an Intune proactive remediation on demand across selected managed devices via Microsoft Graph — built for Intune administrators who need immediate remediation runs outside the assignment schedule.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Bulk Run Remediations On Demand** is a PowerShell script that triggers Intune proactive remediations immediately on one or many managed devices.

The script connects to Microsoft Graph interactively or with app-only client credentials, lists every proactive remediation (device health script) and managed device in the tenant, and lets you pick targets through grid-view pickers. It then posts the `initiateOnDemandProactiveRemediation` action for each device and logs every step. Originally created by Andrew Taylor; migrated to the enterprise standard with retry-aware Graph calls and canonical logging.

---

# ✨ Features

* Interactive MFA sign-in **or** app-only client credentials (`-Tenant`, `-ClientId`, `-ClientSecret`)
* Grid-view pickers for remediation and devices, or fully parameterized unattended runs
* Retry-aware Graph calls (`Invoke-MgGraphRequestWithRetry`: HTTP 429/503 honoring `Retry-After`, max 5 attempts)
* Full pagination of device and remediation collections via `Get-MgGraphAllPages`
* Timestamped, level-colored logging to `C:\ProgramData\Invoke-BulkRemediation\Logs\`

---

# 📂 Project Structure

```text
Invoke-BulkRemediation
│
 ├── Invoke-BulkRemediation.ps1
 └── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Invoke-BulkRemediation.ps1
```
Signs in interactively, then opens the remediation and device pickers.

### With Parameters
```powershell
.\Invoke-BulkRemediation.ps1 -Tenant "contoso.onmicrosoft.com" -ClientId "<app-client-id>" -ClientSecret "<app-secret>" -RemediationId "<deviceHealthScript-id>" -DeviceId "<managed-device-id-1>","<managed-device-id-2>"
```
App-only authentication targeting explicit devices — ideal for automation and headless sessions.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| Tenant | String | No | Empty | Tenant domain/ID for app-only authentication |
| ClientId | String | No | Empty | Application (Client) ID of the app registration |
| ClientSecret | String | No | Empty | Client secret — supply from a secret store at runtime |
| RemediationId | String | No | Empty | Device health script ID; picker opens when omitted |
| DeviceId | String[] | No | Empty | Managed device IDs; picker opens when omitted |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Remediation triggered on all chosen devices |
| 1    | Script error (authentication, Graph call, or cancellation) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (desktop PowerShell host required for `Out-GridView` pickers)

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Interactive mode user scopes: `Group.ReadWrite.All`, `Device.ReadWrite.All`, `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementServiceConfig.ReadWrite.All`, `GroupMember.ReadWrite.All`, `Domain.ReadWrite.All`, `Organization.Read.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementScripts.ReadWrite.All`
* App-only mode: matching application permissions with admin consent on the app registration
* Intune Service Administrator role recommended for the operating account

### Logging
* `C:\ProgramData\Invoke-BulkRemediation\Logs\`

---

# 🛡 Operational Notes
* All endpoints intentionally remain on the Graph **beta** service, matching the legacy behavior exactly.
* The on-demand request body keeps its historical payload shape (including its original trailing comma) so tenant-side behavior is unchanged.
* When devices are passed as raw IDs via `-DeviceId`, the legacy display-name lookup is skipped — the trigger still uses each raw ID directly.
* Grid view requires a desktop session; on headless hosts always pass `-RemediationId` and `-DeviceId`.
* Client secrets are never hardcoded — inject them from Azure Key Vault, SecretManagement, or a PSCredential at runtime.

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
