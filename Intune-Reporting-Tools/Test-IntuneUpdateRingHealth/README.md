<div align="center">

# 📊 Test Intune Update Ring Health

**Audits Windows Update ring configurations against Microsoft best practices.**

Checks every update ring against Microsoft's Autopatch-recommended values and common misconfiguration patterns. Flags: excessive quality deferrals (>14 days), missing deadlines, zero grace periods, paused rings, feature deferral conflicts, drivers excluded conflicts, delivery optimization misconfigurations, active hours not configured, devices in multiple rings, rings with no assignments, and inconsistent deadline/grace ratios across rings.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Test Intune Update Ring Health** is a PowerShell reporting script that checks every update ring against Microsoft's Autopatch-recommended values and common misconfiguration patterns. Flags: excessive quality deferrals (>14 days), missing deadlines, zero grace periods, paused rings, feature deferral conflicts, drivers excluded conflicts, delivery optimization misconfigurations, active hours not configured, devices in multiple rings, rings with no assignments, and inconsistent deadline/grace ratios across rings.

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
Test-IntuneUpdateRingHealth
│
├── Test-IntuneUpdateRingHealth.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Test-IntuneUpdateRingHealth.ps1
```

### Example 1
```powershell
.\Test-IntuneUpdateRingHealth.ps1
```
Audits Windows Update ring configurations against Microsoft best practices.


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
* `DeviceManagementConfiguration.Read.All`

### Logging
* `C:\ProgramData\test-intuneupdateringhealth\Logs\`

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
