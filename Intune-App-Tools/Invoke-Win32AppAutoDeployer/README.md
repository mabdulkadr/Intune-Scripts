<div align="center">

# 💻 Intune Win32 App AutoDeployer

**Intune Win32 App AutoDeployer**

Automated Winget-to-Win32 packaging and deployment CLI for Microsoft Intune — select applications from Winget and this tool builds the Entra groups, install/uninstall/detection scripts, IntuneWin package, auto-update Proactive Remediation, and group assignments end-to-end via Microsoft Graph.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Win32 App AutoDeployer** is a PowerShell script that bulk-deploys Winget applications as Win32 LOB apps into Microsoft Intune using the Microsoft Graph API.

For every selected app the tool creates Install/Uninstall Entra security groups, generates the install, uninstall, and detection scripts, packages everything into IntuneWin format, uploads it to Intune, creates an hourly Proactive Remediation that keeps the app updated, and assigns the app to the target groups — optionally also publishing it as Available for users and/or devices. It runs interactively (Winget GridView picker) or fully unattended with app-only Graph authentication, which makes it suitable for Azure Automation webhooks with Git log backup. Based on the original Win32App-AutoDeployer by Andrew Taylor.

---

# ✨ Features

* Interactive app selection via Winget GridView, or unattended runs with `-appid` / `-appname`
* Automatic creation of Install and Uninstall Entra security groups (reuses existing groups when names match)
* Packaging into IntuneWin format and upload as a Win32 LOB app with custom detection and return codes
* Hourly Proactive Remediation pair that silently upgrades outdated Winget apps
* Assignment intents: Required install, Required uninstall, plus optional Available for Users, Devices, or Both
* App-only authentication (tenant/client id/secret) or delegated interactive consent
* Azure Automation webhook mode with shared-secret check and run-log backup to GitHub, GitLab, or Azure DevOps
* Canonical timestamped logging with level colors (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Graph pagination helper (`Get-MgGraphAllPages`) and throttling-aware retry wrapper honoring `Retry-After`

---

# 📂 Project Structure

```text
Intune-Win32AutoDeployer
│
├── Invoke-Win32AppAutoDeployer.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Invoke-Win32AppAutoDeployer.ps1
```
Launches interactive mode: pick one or more apps from the Winget GridView and confirm verbose output preference.

### With Parameters
```powershell
.\Invoke-Win32AppAutoDeployer.ps1 -appid "Mozilla.Firefox" -appname "Mozilla Firefox" -tenant "contoso.onmicrosoft.com" -clientid "00000000-0000-0000-0000-000000000000" -clientsecret "<secret>" -installgroupname "Firefox Install" -uninstallgroupname "Firefox Uninstall" -availableinstall "User"
```
Runs unattended with app-only Graph authentication and pre-defined group names.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| appid | String | No | "" | The exact Winget App ID to deploy |
| appname | String | No | "" | The exact Winget application name |
| tenant | String | No | "" | Tenant ID for app-only authentication |
| clientid | String | No | "" | Azure AD app registration (client) ID |
| clientsecret | String | No | "" | Azure AD app registration secret |
| installgroupname | String | No | "" | Custom name for the install group |
| uninstallgroupname | String | No | "" | Custom name for the uninstall group |
| availableinstall | String | No | "None" | Publish as Available: Users, Devices, Both, or None |
| WebHookData | Object | No | $null | Azure Automation webhook payload (includes webhooksecret) |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** — under PowerShell 7 the script relaunches itself in 5.1 automatically

### Permissions
* Microsoft Graph: `DeviceManagementApps.ReadWrite.All`, `DeviceManagementConfiguration.ReadWrite.All`, `Group.ReadWrite.All`, `GroupMember.ReadWrite.All`
* Intune Service Administrator role (or equivalent) to consent and deploy

### Logging
* `C:\ProgramData\Invoke-Win32AppAutoDeployer\Logs\`

---

# 🛡 Operational Notes
* **Mutates the Intune tenant**: groups, apps, assignments, and Proactive Remediations are created — always test against a staging tenant first.
* Working files are staged under `C:\Temp\<random>-<timestamp>\`; clean the folder periodically after large batch runs.
* In webhook mode the shared secret is compared against `$webhooksecret` in the script body — set it before production use (empty string accepts any value).
* Azure DevOps log backup calls an `Add-DevopsFile` helper that must exist in the session.
* Graph GET calls (pagination, file-processing polls, group lookups) retry up to 5 times on HTTP 429/503, honoring `Retry-After`.
* Module installation targets `CurrentUser` scope; first run on a device downloads several Microsoft.Graph modules.

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
