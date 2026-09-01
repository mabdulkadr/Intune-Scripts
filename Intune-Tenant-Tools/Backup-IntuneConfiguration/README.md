<div align="center">

# 🏢 Backup Intune Configuration

**Exports Intune configuration to versionable JSON with manifest-tracked backups.**

Exports device configuration profiles, settings catalog policies, compliance policies, ADMX templates, and platform scripts as per-object JSON with assignments for source-controlled tenant backups — built for Intune administrators.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Backup Intune Configuration** is a PowerShell script that exports the core Intune configuration surfaces to a timestamped backup folder — device configuration profiles, settings catalog policies (including their full setting bodies), compliance policies, administrative template (ADMX) policies with definition values, and platform scripts — each object as one JSON file including assignments plus a manifest for change tracking and restore.

---

# ✨ Features

* Exports five surfaces: DeviceConfigurations, SettingsCatalog (with per-policy `settings` expansion), CompliancePolicies (`scheduledActionsForRule`), AdmxPolicies (`definitionValues` + `presentationValues`), and PlatformScripts (Windows + macOS)
* Uses `ConvertTo-Json -Depth 25` (manifest depth 5) so nested settings catalog and ADMX presentation values survive round-tripping
* Workstation dual-mode auth: interactive delegated sign-in (MgGraphCommunity WAM-free) or app-only `-TenantId`/`-ClientId` + `-ClientSecret` / `-CertificateThumbprint`
* Throttling-aware pagination (`Get-MgGraphAllPages` + `Invoke-MgGraphRequestWithRetry` honoring `Retry-After`, max 5 attempts / 60s) on beta Graph endpoints
* Structured, timestamped logging to `C:\ProgramData\backup-intune-configuration\Logs\` with `Write-Banner` / `Write-Log` / `Finish-Script`

---

# 📂 Project Structure

```text
Backup-IntuneConfiguration
│
├── Backup-IntuneConfiguration.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Backup-IntuneConfiguration.ps1
```
Exports all supported configuration areas to a timestamped folder beside the script using interactive sign-in.

### With Parameters
```powershell
.\Backup-IntuneConfiguration.ps1 -OutputPath "C:\IntuneBackups" -Areas DeviceConfigurations,CompliancePolicies -SkipScriptContent "true"
```
Exports only classic configuration profiles and compliance policies to `C:\IntuneBackups` while skipping base64 script bodies — app-only example: add `-TenantId <id> -ClientId <id> -ClientSecret <secret>`.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| OutputPath | String | No | "." | Folder in which the timestamped backup folder is created (relative paths resolve beside the script) |
| Areas | String[] | No | All 5 areas | Configuration areas to export: DeviceConfigurations, SettingsCatalog, CompliancePolicies, AdmxPolicies, PlatformScripts |
| SkipScriptContent | String | No | false | When `"true"`, skips downloading base64 script bodies of platform scripts |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing Microsoft.Graph modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication (inject from secret store) |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication (alternative to client secret) |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Backup completed — all requested areas exported with manifest |
| 1    | Script error (authentication, Graph call, or file-system failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.Read.All` (delegated) or matching application permission with admin consent; Entra role: Intune Administrator for reads.

### Logging
* `C:\ProgramData\backup-intune-configuration\Logs\`

---

# 🛡 Operational Notes

* **Backup JSON depth 25:** each object is written with `ConvertTo-Json -Depth 25` (manifest uses depth 5) so nested settings catalog and ADMX presentation values survive round-tripping; Graph never returns secret values (encrypted OMA-URI, passwords, certificates) — those appear as secret references and must be re-entered manually after restore.
* Beta Graph endpoints are used intentionally because the full Intune configuration surface is not exposed on `v1.0`; all calls page with `Get-MgGraphAllPages` and retry on 429/503.
* Relative `-OutputPath` values resolve beside the script (`$PSScriptRoot`), not the caller working directory; logs are timestamped and level-colored.
* **RBAC sensitivity:** backup contains tenant configuration metadata — treat exported JSON and manifest as sensitive; restrict access to the backup folder.
* Test restore in a staging tenant before production; do not run against production without a verified backup.

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
