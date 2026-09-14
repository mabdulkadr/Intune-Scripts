<div align="center">

# 📊 Check Apple Token Validity

**Monitor and report on the validity and expiration status of Apple DEP tokens and Push Notification Certificates in Intune.**

This script connects to Microsoft Graph and retrieves all Apple Device Enrollment Program (DEP) tokens and Apple Push Notification Certificates configured in Intune. It checks their validity status, expiration dates, and sync status to help administrators proactively manage Apple Business Manager integrations. The s...

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Check Apple Token Validity** is a PowerShell reporting script that This script connects to Microsoft Graph and retrieves all Apple Device Enrollment Program (DEP) tokens and Apple Push Notification Certificates configured in Intune. It checks their validity status, expiration dates, and sync status to help administrators proactively manage Apple Business Manager integrations. The s...

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
Test-AppleTokenValidity
│
├── Test-AppleTokenValidity.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Test-AppleTokenValidity.ps1
```

### Example 1
```powershell
.\Test-AppleTokenValidity.ps1
```
Generates Apple token validity reports for all DEP tokens and Push Notification Certificates

### Example 2
```powershell
.\Test-AppleTokenValidity.ps1 -OutputPath "C:\Reports" -ExpirationWarningDays 60
```
Generates reports with 60-day expiration warning and saves to specified directory

### Example 3
```powershell
.\Test-AppleTokenValidity.ps1 -OnlyShowProblems "true" -SendEmailAlert "true" -AlertEmailAddress "<recipient-address>" -SenderUPN "<sender-upn>"
```
Shows only problematic tokens and certificates and sends email alerts for critical issues

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `OutputPath` | string | No | - | Directory path to save reports |
| `ExpirationWarningDays` | int | No | - | Number of days before expiration to show warnings |
| `OnlyShowProblems` | string | No | - | Only show tokens with problems |
| `SendEmailAlert` | string | No | - | Set to true to send email alerts for critical issues |
| `AlertEmailAddress` | string | No | - | Email address to send alerts to |
| `SenderUPN` | string | No | - | User principal name of the mailbox used to send alerts |
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
* `DeviceManagementServiceConfig.Read.All`, `Mail.Send`

### Logging
* `C:\ProgramData\check-apple-token-validity\Logs\`

---

# 🛡 Operational Notes
* Certificates and Apple tokens expire after one year; default warning window is 30 days (`-ExpirationWarningDays` / `-ExpiryWarningDays`) — tune for renewal lead time.
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
