<div align="center">

# ⚙️ Invoke Windows Update Scan

**Intune Proactive Remediation package that scans for and installs pending Windows updates.**

Detection queries the update services through the PSWindowsUpdate module and flags any matching pending updates — remediation then installs them with the same filter set and reports whether a reboot is still required.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke Windows Update Scan** is an Intune remediation package that closes Windows Update gaps on managed devices.

Both scripts share the same configuration block: an update source (`MicrosoftUpdate`), selectable update types, categories, severities, and include/exclude KB article ID lists — empty selections target everything available. The detection script scans read-only (installing PSWindowsUpdate first when missing, as in the legacy pair); when matching updates are pending, the paired remediation installs them via `Install-WindowsUpdate` without forcing a reboot, then checks the standard registry indicators for a pending restart.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Scans `Get-WindowsUpdate` against Microsoft Update or Windows Update
* Filter by type, category, severity, or KB article IDs from one config block
* Invalid configuration values fail fast as script errors (exit 2)
* Installs the PSWindowsUpdate module automatically when missing

### 🔹 Verified Remediation
* Pre-check validates configuration and imports the module before any change
* Installs only the matching updates; no reboot is forced (`IgnoreReboot`)
* Verifies install completion and reports pending-reboot registry keys
* Emits structured JSON result output for Intune diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Invoke-WindowsUpdateScan\`

---

# 📂 Project Structure

```text
Invoke-WindowsUpdateScan
│
├── detect-Invoke-WindowsUpdateScan.ps1
├── remediate-Invoke-WindowsUpdateScan.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Invoke-WindowsUpdateScan.ps1
```

### Purpose
Detects matching pending Windows updates. Read-only apart from installing the PSWindowsUpdate module when absent.

### Logic
1. Validate the configured source, types, categories, and severities
2. Ensure and import the PSWindowsUpdate module
3. Run `Get-WindowsUpdate` with the configured filters
4. Non-compliant when at least one matching update is pending

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Invoke-WindowsUpdateScan.ps1
```

### Purpose
Installs matching Windows updates and reports reboot state, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: validate configuration, ensure/import the module
2. Fix: scan again, then `Install-WindowsUpdate` when matches exist (no forced reboot)
3. Post-verify: require a clean install run or nothing-to-do; check pending-reboot keys

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (fix applied and verified) |
| 1    | Failure (verification failed) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs via Intune in SYSTEM or user context per assignment — no Graph permissions required.
* Access to the PowerShell Gallery is needed when PSWindowsUpdate must be installed.

### Logging
* `<SystemDrive>\IntuneLogs\Invoke-WindowsUpdateScan\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Invoke-WindowsUpdateScan.ps1
```

### Remediation Script
```powershell
remediate-Invoke-WindowsUpdateScan.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` matching updates are pending
3. Intune runs the **Remediation Script**
4. Remediation installs the updates, checks reboot state, and logs results

---

# 🛡 Operational Notes
* `$AutoRebootAfterInstall` stays `$false`: installed updates wait for a normal restart cycle — plan reboot enforcement separately.
* A successful remediation means the install run finished cleanly; updates can still be pending application until the device reboots.
* Both scripts share the selection arrays — keep them identical so detection and remediation always agree on scope.
* The update scan can take several minutes on devices with large backlogs; schedule accordingly.
* Detection errors deliberately exit `2` so Intune never treats a crashed detection as non-compliance.

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
