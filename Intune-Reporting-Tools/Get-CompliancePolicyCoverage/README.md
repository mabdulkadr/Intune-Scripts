<div align="center">

# 📊 Get Compliance Policy Coverage

**Finds device platforms in the tenant that no assigned compliance policy covers.**

This script compares the platforms of all enrolled Intune devices against the platforms targeted by assigned compliance policies. Platforms with enrolled devices but no assigned compliance policy are a real gap: those devices report as compliant by default (or fall to the built-in policy) and can slip through Condit...

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Get Compliance Policy Coverage** is a PowerShell reporting script that This script compares the platforms of all enrolled Intune devices against the platforms targeted by assigned compliance policies. Platforms with enrolled devices but no assigned compliance policy are a real gap: those devices report as compliant by default (or fall to the built-in policy) and can slip through Condit...

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
Get-CompliancePolicyCoverage
│
├── Get-CompliancePolicyCoverage.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Get-CompliancePolicyCoverage.ps1
```

### Example 1
```powershell
.\Get-CompliancePolicyCoverage.ps1
```
Shows the platform coverage matrix and any gaps

### Example 2
```powershell
.\Get-CompliancePolicyCoverage.ps1 -ExportToCsv "true"
```
Exports the coverage report to a timestamped CSV file


---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `ExportToCsv` | string | No | - | Export results to CSV |
| `OutputPath` | string | No | - | Output path for exports |
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
* `DeviceManagementConfiguration.Read.All`, `DeviceManagementManagedDevices.Read.All`

### Logging
* `C:\ProgramData\get-compliance-policy-coverage\Logs\`

---

# 🛡 Operational Notes
* Compliance evaluation is tenant-specific; verify the tenant setting “Mark devices with no compliance policy assigned as” — uncovered platforms may silently pass Conditional Access when set to Compliant.
* Test in a staging tenant first; Graph permission errors surface as 403 — check Entra ID consent for the listed scopes.

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

Adapted in part from github.com/ugurkocde/IntuneAutomation (Ugur Koc, MIT) — see THIRD-PARTY-NOTICES.md.
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
