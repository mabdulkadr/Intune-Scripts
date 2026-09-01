<div align="center">

# 🧩 Intune Driver Approve Bulk

**Intune Driver Approve Bulk**

Approves every pending Windows driver update across all Intune driver update profiles via Microsoft Graph — interactive and app-only variants included.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Approve-IntuneDriverUpdates** is a PowerShell script that bulk-approves Windows driver updates that Intune has flagged as needing review.

For every Windows driver update profile it pulls the full paginated driver inventory filtered to `category eq 'other' and approvalStatus eq 'needsreview'`, then approves each pending driver through the `executeAction` action with an ISO 8601 deployment date. Two variants are provided: an interactive MFA sign-in script and an app-only client-credentials script for unattended automation.

---

# ✨ Features

* Processes **all** driver update profiles in the tenant in one run
* Full pagination of driver inventories via `Get-MgGraphAllPages`
* Retry-aware Graph calls (`Invoke-MgGraphRequestWithRetry`: HTTP 429/503 honoring `Retry-After`, max 5 attempts)
* Two authentication variants: interactive MFA (`Approve-IntuneDriverUpdates.ps1`) and app-only client-credentials (via `-AppId` / `-AppSecret` parameters on the same script)
* `-WhatIf` / `-Confirm` / `-Force` gates — per-profile pending-count preview printed before any approval is sent
* Per-driver approval results logged with timestamped, level-colored lines
* Automatic per-user installation of the required Microsoft Graph modules

---

# 📂 Project Structure

```text
Approve-IntuneDriverUpdates
│
 ├── Approve-IntuneDriverUpdates.ps1
 └── README.md
```

---

# 🚀 Usage

### Interactive Variant (MFA sign-in)
```powershell
.\Approve-IntuneDriverUpdates.ps1
```

### App-Only Variant (client credentials)
```powershell
.\Approve-IntuneDriverUpdates-AppAuth.ps1 -TenantID "<your-tenant-id>" -AppID "<your-application-client-id>" -AppSecret "<secret-from-your-secret-store>"
```
The app registration needs the `DeviceManagementConfiguration.ReadWrite.All` application permission with admin consent.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| TenantID | String | AppAuth only | Placeholder | Azure AD tenant ID or domain for the token request |
| AppID | String | AppAuth only | Placeholder | Application (Client) ID of the app registration |
| AppSecret | String | AppAuth only | Placeholder | Client secret — supply from a secret store at runtime |

The interactive variant takes no parameters.

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Approval pass completed |
| 1    | Script error (module install, authentication, or Graph failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Interactive variant: `DeviceManagementConfiguration.ReadWrite.All` delegated scope, consented at sign-in; Intune Service Administrator role recommended.
* App-only variant: `DeviceManagementConfiguration.ReadWrite.All` application permission with admin consent.

### Logging
* Interactive: `C:\ProgramData\Approve-IntuneDriverUpdates\Logs\`
* App-only: `C:\ProgramData\Approve-IntuneDriverUpdates-AppAuth\Logs\`

---

# 🛡 Operational Notes
* Endpoints stay on the Graph **beta** service (`windowsDriverUpdateProfiles`, `driverInventories`, `microsoft.graph.executeAction`), matching legacy behavior.
* The profile list is read from its first page only (legacy behavior); driver inventories are fully paginated.
* Approvals apply immediately — every driver currently awaiting review gets a deployment date of "now".
* Never hardcode client secrets; retrieve them at runtime from Azure Key Vault or SecretManagement.
* Requires the `Microsoft.Graph.Authentication` and `Microsoft.Graph.Beta.DeviceManagement.Actions` modules (auto-installed per user).

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
