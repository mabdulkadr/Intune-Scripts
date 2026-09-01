<div align="center">

# 🛡️ SecureBoot-CA2023-Update

**Secure Boot CA 2023 certificate migration — fix the June 2026 expiry before revocation in October 2028**

Microsoft's 2011 Secure Boot certificates expire starting June 2026. Devices still on 2011 certs lose future Secure Boot protections. This remediation provisions the CA 2023 update policy so Windows Update migrates certificates on next servicing.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**SecureBoot-CA2023-Update** provisions the registry policy that triggers Windows to migrate Secure Boot certificates from the expiring 2011 CA to the new 2023 CA.

Intune now exposes this as three Settings Catalog policies: **Enable Secureboot Certificate Updates** (mandatory), **Configure Microsoft Update Managed Opt In**, and **Configure High Confidence Opt Out**. This remediation provides the registry-level fallback for devices that cannot receive the Settings Catalog policy or need immediate enforcement without waiting for policy sync.

The remediation writes `HKLM\SYSTEM\CurrentControlSet\Control\SecureBoot\AvailableUpdatePolicy = 5944` (DWORD). Windows Update servicing then migrates certificates over the next 1–3 reboots.

---

# ✨ Core Features

### 🔹 2011 → 2023 Certificate Migration
* Detects missing or incorrect `AvailableUpdatePolicy` and provisions the correct value `5944`
* Validates Secure Boot is enabled before migrating (skips VMs without UEFI)

### 🔹 Safe & Idempotent
* Read-only detection — never modifies the system
* Remediation verifies the value persists before reporting success

---

# 📂 Project Structure

```text
SecureBoot-CA2023-Update
│
├── detect-SecureBoot-CA2023-Update.ps1
├── remediate-SecureBoot-CA2023-Update.ps1
└── README.md
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-SecureBoot-CA2023-Update.ps1
```

### Purpose
Checks whether Secure Boot CA 2023 migration is provisioned. Read-only, never modifies the system.

### Logic
1. Check Secure Boot is enabled via `Confirm-SecureBootUEFI` (skip if undeterminable)
2. Read `HKLM\...\SecureBoot\AvailableUpdatePolicy` — expect DWORD `5944`
3. Log `UEFICA2023Status` / `AvailableUpdates` for operator visibility

### 📊 Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-SecureBoot-CA2023-Update.ps1
```

### Purpose
Creates the Secure Boot policy registry value and verifies it persists. The actual certificate migration completes via Windows Update servicing on next reboot(s).

### 📊 Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (22H2+, 24H2 recommended)

### PowerShell
* PowerShell **5.1 or later**

### 🔐 Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\SecureBoot-CA2023-Update\`

---

# 🧭 Intune Deployment

### 🔎 Detection Script
```powershell
detect-SecureBoot-CA2023-Update.ps1
```

### 🛠 Remediation Script
```powershell
remediate-SecureBoot-CA2023-Update.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

**Alternative (preferred):** Deploy via Settings Catalog → Secure Boot → Enable Secureboot Certificate Updates. Use this remediation as a fallback for devices that cannot receive the catalog policy.

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `0` (compliant) or `1` (non-compliant)
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation writes `AvailableUpdatePolicy=5944`, verifies it, and logs JSON result
5. Device reboots 1–3 times over next servicing window to complete migration; monitor via Intune Secure Boot Status Report

---

# 🛡 Operational Notes
* **Does not reboot.** Schedule reboots separately or let Windows Update handle them.
* **Monitor:** Intune admin center → Reports → Secure Boot Status Report
* **Multiple reboots may be required** — firmware errors may persist in Event Viewer after first reboot; give 2–3 cycles.
* **BitLocker:** The migration does not require BitLocker suspension — only BIOS-level Secure Boot enablement does.
* **References:** [Secure the Windows boot process](https://learn.microsoft.com/en-us/windows-hardware/design/device-experiences/oem-secure-boot) · [KB5095093](https://support.microsoft.com/en-us/topic/june-23-2026-kb5095093-os-builds-26200-8737-and-26100-8737-preview-0e2a20f2-cf9e-46f8-9f08-e6996220882d)

---

## 👤 Author

**Mohammad Abdelkader Omar**  
GitHub: [@mabdulkadr](https://github.com/mabdulkadr)  
Website: [momar.tech](https://momar.tech)

---

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
