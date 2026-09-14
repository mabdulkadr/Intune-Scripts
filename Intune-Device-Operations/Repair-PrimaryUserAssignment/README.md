<div align="center">

# 📱 Fix Primary User Assignment

**Aligns each Windows device's Intune primary user with the user who actually logs on to it.**

This script compares every Windows device's Intune primary user with the most
    recent logged-on user reported by the device (usersLoggedOn).

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Fix Primary User Assignment** is a PowerShell script that This script compares every Windows device's Intune primary user with the most recent logged-on user reported by the device (usersLoggedOn). Devices whose primary user differs from the actual user - shared-device handovers, re-imaged machines, IT-technician enrollments - are reported, and with -Apply the primary user is updated via the users/`$ref assignment. A correct primary user matters for self-service portal access, user-targeted policy resolution, and license-based app delivery. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used.

This script compares every Windows device's Intune primary user with the most recent logged-on user reported by the device (usersLoggedOn). Devices whose primary user differs from the actual user - shared-device handovers, re-imaged machines, IT-technician enrollments - are reported, and with -Apply the primary user is updated via the users/`$ref assignment. A correct primary user matters for self-service portal access, user-targeted policy resolution, and license-based app delivery. Workstation authentication modes: - Interactive (default): auto-installs Microsoft.Graph.Authentication if missing and connects with delegated scopes via Connect-MgGraph / Connect-MgGraphCommunity (WAM-free when available). - App-only (optional): provide -TenantId, -ClientId and either -ClientSecret or -CertificateThumbprint for unattended service-principal authentication. Pass -TenantId, -ClientId and -ClientSecret (or -CertificateThumbprint) together to use app-only; otherwise interactive delegated authentication is used. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Compares `usersLoggedOn` (most-recent logon) to Intune primary user on Windows devices
* `-Apply "true"` corrects via `users/$ref` after resolving enabled UPNs
* Report-only by default; `-WhatIf` previews changes without applying
* Resolves user UPN via enabled account filtering for accuracy
* Detailed per-device mismatch report with before/after UPN

---

# 📂 Project Structure

```text
Repair-PrimaryUserAssignment
│
├── Repair-PrimaryUserAssignment.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\fix-primary-user-assignment.ps1
```
Reports devices whose primary user does not match the last logged-on user

### Example 2
```powershell
.\fix-primary-user-assignment.ps1 -Apply "true" -WhatIf
```
Previews the primary user changes without applying them

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `TenantId` | String | No | `` | Tenant ID for app-only auth |
| `ClientId` | String | No | `` | Client ID for app-only auth |
| `ClientSecret` | String | No | `` | Client secret (or use `CertificateThumbprint`) |
| `CertificateThumbprint` | String | No | `` | Certificate thumbprint for app-only auth |
| Common switches | String | No | — | Tool-specific flags described in EXAMPLES — see Usage above |

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
* `DeviceManagementManagedDevices.ReadWrite.All,User.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.

### Logging
* `C:\ProgramData\fix-primary-user-assignment\Logs`

---

# 🛡️ Operational Notes

* Remote bulk operations support `-DryRun` / `-WhatIf` previews — use them before any write or destructive action.
* Graph scripts honor HTTP 429 throttling with 60-second back-off and support pagination via `Get-MgGraphAllPages`.
* CSV bulk operations are idempotent; re-running the same CSV without changes is a no-op.
* Test in a staging tenant or on a pilot Entra group before production; export reports for change control.

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
