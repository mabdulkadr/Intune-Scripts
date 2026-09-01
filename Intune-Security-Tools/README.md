<div align="center">

# 🔒 Intune Security Tools

**Encryption and endpoint protection auditing**

[![Intune](https://img.shields.io/badge/Intune-Security%20Tools-10B981?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%26%20macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [Operational Notes](#-operational-notes) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Security Tools** is a focused collection of workstation-run auditing and rotation scripts for encryption and endpoint protection in Microsoft Intune.

The category covers BitLocker and FileVault key lifecycle, Windows LAPS escrow, Microsoft Defender health, and endpoint security policy coverage (Firewall, Attack Surface Reduction, Antivirus, Disk Encryption, EDR, Account Protection). Every script runs **LocalOnly from an admin workstation** via Microsoft Graph — interactive delegated sign-in (WAM-free via `MgGraphCommunity`) or app-only (`-TenantId` / `-ClientId` / `-ClientSecret` or `-CertificateThumbprint`) — with no Azure Automation dependency.

> **Vault-destination note:** `Backup-BitLockerKeysToKeyVault.ps1` legitimately touches **Azure Key Vault** (`https://vault.azure.net`) as a **RESOURCE** — a vault-destination for escrowed BitLocker secrets — not as an Automation runbook. See Operational Notes.

---

# ✨ Core Features

### 🔹 Encryption Lifecycle
* Back up BitLocker recovery keys from Entra ID to Azure Key Vault as per-volume secrets with device tags
* Rotate BitLocker recovery keys tenant-wide via Graph `rotateBitLockerKeys`
* Rotate macOS FileVault / LAPS passwords via Graph `rotateLocalAdminPassword` with TestMode and per-device targeting

### 🔹 Endpoint Protection Auditing
* Defender health: real-time protection, tamper protection, signature currency, overdue scans, pending reboot, and `NotReported` devices
* Firewall & ASR coverage: inventories endpoint security policies (settings catalog + legacy intents) and flags disciplines with no assigned policy
* Windows LAPS audit: cross-references Entra `deviceLocalCredentials` against Intune Windows devices via `azureADDeviceId`

### 🔹 Enterprise Execution
* Structured logging to `$env:ProgramData\<SolutionName>\Logs` with `Write-Banner` / `Write-Log`
* Beta Graph endpoints where the surface requires it; paging with 429 throttling and one retry after 60s
* Portal-safe string-boolean parameters with typed validation; CSV export where applicable

---

# 📂 Project Structure

```text
Intune-Security-Tools
│
├── Backup-BitLockerKeysToKeyVault.ps1
├── Get-DefenderStatusReport.ps1
├── Get-FirewallAsrStatus.ps1
├── Get-WindowsLapsAudit.ps1
├── Rotate-BitLockerRecoveryKeys.ps1
├── Rotate-MacOsFileVaultPasswords.ps1
└── README.md
```

---

# 📜 Scripts Included

| Script | Purpose | Permissions | Run Context | Notes |
| ------ | ------- | ----------- | ----------- | ----- |
| `Backup-BitLockerKeysToKeyVault.ps1` | Backs up BitLocker recovery keys from Entra ID (`informationProtection/bitlocker/recoveryKeys`) to Azure Key Vault as secrets `BitLocker-{DeviceName}-{SerialNumber}-{VolumeType}` with tags | `DeviceManagementManagedDevices.Read.All`, `BitlockerKey.Read.All` + Key Vault **Secrets Officer** (ABAC) or Administrator on the target vault | Workstation — interactive delegated (device-code + browser, WAM-free) or app-only (`-TenantId`/`-ClientId`/`-ClientSecret` or `-CertificateThumbprint`). **LocalOnly** | **Vault-destination RESOURCE:** writes to `https://vault.azure.net` via REST (`Invoke-MgGraphCommunityRequest` with a separate Key Vault-audience token). Not an Azure Automation runbook. Requires `-VaultUri https://<vault>.vault.azure.net`. |
| `Get-DefenderStatusReport.ps1` | Reports Defender health across all Windows devices: protection state, signature age, devices needing attention | `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only. **LocalOnly** | Fetches tenant `deviceProtectionOverview` + per-device `windowsProtectionState` (one request per device); `-OnlyIssues` / `-ExportToCsv` |
| `Get-FirewallAsrStatus.ps1` | Inventories endpoint security policy coverage per discipline (Firewall, ASR, Antivirus, Disk Encryption, EDR, Account Protection) and flags unassigned disciplines | `DeviceManagementConfiguration.Read.All`, `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only. **LocalOnly** | Settings catalog filtering is client-side on `templateFamily = endpointSecurity*`; legacy `deviceManagement/intents` included |
| `Get-WindowsLapsAudit.ps1` | Audits Windows LAPS escrow: which devices have a backed-up local admin password and how stale it is | `DeviceLocalCredential.ReadBasic.All`, `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only. **LocalOnly** | Cross-references Entra `deviceLocalCredentials` via `azureADDeviceId`; never retrieves password values |
| `Rotate-BitLockerRecoveryKeys.ps1` | Rotates BitLocker recovery keys for all Windows devices via `rotateBitLockerKeys` | `DeviceManagementManagedDevices.ReadWrite.All` | Workstation — interactive or app-only. **LocalOnly** | Supports `-DryRun` preview and `-Force` to skip confirmation |
| `Rotate-MacOsFileVaultPasswords.ps1` | Rotates macOS LAPS / FileVault local admin passwords via `rotateLocalAdminPassword` | `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only. **LocalOnly** | Personal devices are skipped; `-TestMode`, `-DeviceName`/`-DeviceId`, `-DeviceLimit`, `-ExportReport` supported |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (admin workstation)

### PowerShell
* PowerShell **5.1 or later**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed if missing; `MgGraphCommunity >= 1.4.0` for WAM-free interactive sign-in)
* No `Az` modules required — Key Vault is accessed via REST

### Permissions
* Per-script Graph permissions as listed above (least-privilege; consent on first interactive sign-in or pre-consent via Entra Enterprise Applications)
* Key Vault RBAC for the backup script: **Key Vault Secrets Officer** or **Key Vault Administrator** on the destination vault
* Intune Administrator or equivalent role for LAPS credential metadata

### Run Context
* **LocalOnly** — run from an admin workstation, not from an Intune device context or Azure Automation runbook

---

# 🛡 Operational Notes

* **BitLocker rotation — `DryRun` / `Force`:** `Rotate-BitLockerRecoveryKeys.ps1` defaults to an interactive confirmation gate. Use `-DryRun "true"` to list the Windows devices that *would* be targeted without rotating any keys. Use `-Force "true"` to skip the prompt for unattended / scripted runs (still workstation-run, not Automation). Rotation is throttled with one automatic retry after 60s on `429`.
* **macOS FileVault rotation — `TestMode` / `Force`:** `Rotate-MacOsFileVaultPasswords.ps1` supports `-TestMode "true"` (no rotation, reports intent) and `-DeviceLimit` for controlled rollouts. `-Force "true"` skips the confirmation prompt. Personal (`ownerType == personal`) devices are skipped — LAPS rotation is not supported on personal devices. Throttling is retried once after 60s.
* **Windows LAPS audit — `azureADDeviceId` cross-reference:** `Get-WindowsLapsAudit.ps1` indexes Entra `deviceLocalCredentials` by `id` (which is the Entra device ID) and joins to Intune `managedDevices` via `azureADDeviceId`. Devices without escrow, stale passwords (`-MaxPasswordAgeDays`, default 60), and `EscrowedNoTimestamp` are reported separately. Status buckets: `Healthy` / `Stale` / `NotEscrowed` / `EscrowedNoTimestamp`.
* **Azure Key Vault — audience warning:** `Backup-BitLockerKeysToKeyVault.ps1` acquires **two separate tokens with different audiences**: a device-code token for `https://vault.azure.net/user_impersonation` (Key Vault) and a browser token for Graph (`DeviceManagementManagedDevices.Read.All`, `BitlockerKey.Read.All`). One token cannot serve both resources. The script switches `MgGraphCommunity` sessions per call (`Select-MgGraphCommunityContext`) and restores the Graph session after each Key Vault `PUT`. Secret names are sanitized (`[^a-zA-Z0-9-] → -`) and carry a stable `-{VolumeType}` suffix; `-OverwriteExisting` honors existing secret versions.
* **Defender report — per-device cost:** `Get-DefenderStatusReport.ps1` issues one `windowsProtectionState` request per Windows device; large tenants take minutes and may hit throttling. `-OnlyIssues "true"` filters to actionable rows.
* **Firewall/ASR — coverage semantics:** `Get-FirewallAsrStatus.ps1` reports *assigned policy existence* per discipline, not per-device applicability. A `GAP` means no assigned policy for that discipline — devices run on local defaults.
* **Common:** All scripts disconnect (`Disconnect-MgGraph` / `Disconnect-MgGraphCommunity`) and write structured logs. Test in a staging tenant/device group before production.

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

## 📜 Attribution

Adapted from [ugurkocde/IntuneAutomation](https://github.com/ugurkocde/IntuneAutomation). See [THIRD-PARTY-NOTICES.md](../../THIRD-PARTY-NOTICES.md) for full upstream license, preserved `.AUTHOR`/`.CHANGELOG` fields, and excluded Azure-only assets. **Clarification — Key Vault destination:** `Backup-BitLockerKeysToKeyVault.ps1` writes to Azure Key Vault (`https://vault.azure.net`) as a **vault-destination RESOURCE** (audience-specific REST writes via `Invoke-MgGraphCommunityRequest`), not as an Azure Automation runbook — no Automation dependency or Managed Identity code path is introduced; the remaining scripts in this folder do not touch Azure at all.

---

<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>
