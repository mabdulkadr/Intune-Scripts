<div align="center">

# 🏢 Restore Intune Configuration

**Recreates Intune objects from a JSON backup with optional assignment restore.**

Restores profiles, policies, and scripts as new entries from a Backup-IntuneConfiguration folder — supports `-WhatIf` preview and assignment rehydration.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Restore Intune Configuration** is a PowerShell script that reads a backup folder produced by `Backup-IntuneConfiguration` and recreates the exported objects in the target tenant — device configuration profiles, settings catalog policies, compliance policies, ADMX policies with definition values, and platform scripts — always as new entries (no in-place overwrite), stripping read-only properties (`id`, timestamps, `assignments`, `@odata.*`) and optionally restoring assignments when source group IDs exist in the target.

---

# ✨ Features

* Declares `[CmdletBinding(SupportsShouldProcess = $true)]` — every create is gated by `$PSCmdlet.ShouldProcess`; run `-WhatIf` to preview without writing
* Handles `scheduledActionsForRule` fallbacks and ADMX `definition@odata.bind` creation; uses `-Depth 25` (settings catalog 30) on create payloads
* Optional `-RestoreAssignments` (off by default) rehydrates group assignments; failures are per-object and do not stop the restore
* Supports `-NamePrefix` and `-Areas` filtering; re-running with the same backup creates duplicates by design
* Workstation dual-mode auth and structured logging to `C:\ProgramData\restore-intune-configuration\Logs\`

---

# 📂 Project Structure

```text
Restore-IntuneConfiguration
│
├── Restore-IntuneConfiguration.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Restore-IntuneConfiguration.ps1 -BackupPath ".\IntuneConfigBackup_2026-07-20_10-00-00" -WhatIf
```
Previews everything that would be created without writing to the tenant — honors `SupportsShouldProcess`.

### With Parameters
```powershell
.\Restore-IntuneConfiguration.ps1 -BackupPath ".\IntuneConfigBackup_2026-07-20_10-00-00" -Areas CompliancePolicies -RestoreAssignments "true" -NamePrefix "Restored - "
```
Restores only compliance policies with a name prefix and rehydrates assignments (requires source group IDs to exist in target tenant).

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| BackupPath | String | Yes | - | Path to a folder created by Backup-IntuneConfiguration.ps1 |
| Areas | String[] | No | All 5 areas | Configuration areas to restore: DeviceConfigurations, SettingsCatalog, CompliancePolicies, AdmxPolicies, PlatformScripts |
| RestoreAssignments | String | No | false | When `"true"`, also restores group assignments (requires source group IDs to exist in target tenant) |
| NamePrefix | String | No | "" | Prefix added to restored object names, e.g. 'Restored - ' |
| ForceModuleInstall | String | No | false | When `"true"`, auto-installs missing modules without prompting |
| TenantId | String | No | None | Entra tenant ID for app-only authentication |
| ClientId | String | No | None | App registration client ID for app-only authentication |
| ClientSecret | String | No | None | Client secret for app-only authentication |
| CertificateThumbprint | String | No | None | Certificate thumbprint for app-only authentication |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Restore completed — objects created (or previewed with -WhatIf) |
| 1    | Script error (missing backup, authentication, or Graph create failure) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.ReadWrite.All` (delegated or application with admin consent); Entra role: Intune Administrator / Service Administrator for writes.

### Logging
* `C:\ProgramData\restore-intune-configuration\Logs\`

---

# 🛡 Operational Notes

* **Restore supports ShouldProcess / WhatIf:** the script is declared with `[CmdletBinding(SupportsShouldProcess = $true)]` — every `deviceConfigurations`, `configurationPolicies`, `deviceCompliancePolicies`, `groupPolicyConfigurations`, and `deviceManagementScripts` create is gated by `$PSCmdlet.ShouldProcess`; run with `-WhatIf` to preview.
* Objects are always created as new entries; re-running with the same backup creates duplicates — existing policies with the same name are not touched.
* Secret values (encrypted OMA-URI, passwords, certificates) are never present in Graph exports; re-enter them manually after restore.
* **Backup JSON depth 25:** companion backup writes each object with `ConvertTo-Json -Depth 25` (manifest depth 5) so nested values survive round-tripping; restore uses depth 25 (settings catalog 30).
* **RBAC sensitivity:** assignment restore (`-RestoreAssignments`) requires source group IDs to exist in the target tenant and is reported per object; unresolvable ADMX definitions are skipped with a warning.

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
