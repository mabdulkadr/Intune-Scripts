<div align="center">

# 🔒 BitLocker Keys Backup to Azure Key Vault

**Backs up BitLocker recovery keys from Entra ID to Azure Key Vault using REST API.**

This script connects to Microsoft Graph API to retrieve BitLocker recovery keys for Windows devices,
    then stores them securely in Azure Key Vault using REST API.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.5.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**BitLocker Keys Backup to Azure Key Vault** is a PowerShell script that This script connects to Microsoft Graph API to retrieve BitLocker recovery keys for Windows devices, then stores them securely in Azure Key Vault using REST API. Each key is stored as a secret with device information (name and serial number) included in tags. Authentication uses the MgGraphCommunity module (WAM-free) and acquires two separate tokens with the correct audiences: a device code sign-in for Azure Key Vault (https://vault.azure.net) and an interactive browser sign-in for Microsoft Graph. No Az modules are needed. On first run, you will be prompted to consent to the required permissions including Key Vault access. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency.

This script connects to Microsoft Graph API to retrieve BitLocker recovery keys for Windows devices, then stores them securely in Azure Key Vault using REST API. Each key is stored as a secret with device information (name and serial number) included in tags. Authentication uses the MgGraphCommunity module (WAM-free) and acquires two separate tokens with the correct audiences: a device code sign-in for Azure Key Vault (https://vault.azure.net) and an interactive browser sign-in for Microsoft Graph. No Az modules are needed. On first run, you will be prompted to consent to the required permissions including Key Vault access. Workstation dual-mode: interactive (delegated, auto-installs MgGraphCommunity when missing) and app-only via -TenantId, -ClientId and -ClientSecret or -CertificateThumbprint. No Azure Automation dependency. It runs **against Microsoft Graph via workstation authentication (interactive delegated through MgGraphCommunity or app-only with client credentials)** and writes structured logs for every operation.

---

# ✨ Features

* Backs up BitLocker recovery keys from Entra ID to Azure Key Vault
* Stores each volume as secret `BitLocker-{DeviceName}-{SerialNumber}-{VolumeType}` with device tags
* Dual-audience tokens: Key Vault (`https://vault.azure.net`) via device-code and Graph via browser (WAM-free)
* Session switching via `Select-MgGraphCommunityContext` restores Graph after each Key Vault PUT
* Sanitized secret names (`[^a-zA-Z0-9-] -> -`) with stable VolumeType suffix and `-OverwriteExisting` honor

---

# 📂 Project Structure

```text
Backup-BitLockerKeysToKeyVault
│
├── Backup-BitLockerKeysToKeyVault.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\backup-bitlocker-keys-to-keyvault.ps1 -VaultUri "https://bitlockerfilevaultkeys.vault.azure.net"
```
Backs up all BitLocker keys to the specified Azure Key Vault

### Example 2
```powershell
.\backup-bitlocker-keys-to-keyvault.ps1 -VaultUri "https://myvault.vault.azure.net" -OverwriteExisting "true" -ShowProgress "true"
```
Backs up keys with overwrite option and progress display

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `VaultUri` | String | Yes | — | Azure Key Vault URI (e.g., `https://myvault.vault.azure.net`) |
| `OverwriteExisting` | String | No | `false` | Overwrite existing secrets (`"true"`) |
| `ShowProgress` | String | No | `false` | Show per-device progress bar (`"true"`) |
| `TenantId` / `ClientId` / `ClientSecret` / `CertificateThumbprint` | String | No | `` | App-only auth; omit for interactive dual-token flow |

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
* No `Az` modules required — Key Vault is accessed via REST

### Permissions
* `DeviceManagementManagedDevices.Read.All,BitlockerKey.Read.All` — grant exactly the listed delegated or application permissions and consent as admin before running.
* Key Vault RBAC: **Key Vault Secrets Officer** or **Key Vault Administrator** on the target vault

### Logging
* `C:\ProgramData\backup-bitlocker-keys-to-keyvault\Logs`

---

# 🛡️ Operational Notes

* **Vault-destination note:** `Backup-BitLockerKeysToKeyVault.ps1` legitimately touches **Azure Key Vault** (`https://vault.azure.net`) as a **RESOURCE** — a vault-destination for escrowed BitLocker secrets — not as an Automation runbook. Requires `-VaultUri https://<vault>.vault.azure.net` and Key Vault **Secrets Officer** (ABAC) or Administrator on the target vault.
* Acquires **two separate tokens with different audiences**: device-code for `https://vault.azure.net/user_impersonation` and browser for Graph (`DeviceManagementManagedDevices.Read.All`, `BitlockerKey.Read.All`). One token cannot serve both resources; the script switches `MgGraphCommunity` sessions per call and restores Graph after each Key Vault PUT.
* Secret names are sanitized (`[^a-zA-Z0-9-] -> -`) and carry stable `-{VolumeType}` suffix; `-OverwriteExisting` honors existing versions.
* No `Az` modules required — Key Vault is accessed via REST (`Invoke-MgGraphCommunityRequest`).

---

## 👤 Author
**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

**Mohammad Abdelkader Omar** (maintainer) — original author: **Ugur Koc**  
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
