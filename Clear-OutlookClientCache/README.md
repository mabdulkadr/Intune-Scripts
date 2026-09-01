<div align="center">

# 🪟 Clear Outlook Client Cache

**Intune Proactive Remediation package that clears the Outlook autocomplete cache on devices where Outlook is installed.**

Detection verifies the `OUTLOOK.EXE` installation path and remediation starts Outlook with `/cleanautocompletecache /recycle` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Clear Outlook Client Cache** is an Intune remediation package that purges the Outlook autocomplete cache across managed devices.

The detection script checks for `C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE`: when Outlook is present its autocomplete cache may hold stale or incorrect recipient entries, so Intune runs the paired remediation, which launches Outlook with `/cleanautocompletecache` and `/recycle` to clear the cache during startup. Devices without Outlook exit compliant because there is no client cache to clean.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Tests for `OUTLOOK.EXE` under the Office16 click-to-run root
* Never modifies the system during detection
* Detection errors exit `2` so Intune never treats a crash as non-compliance

### 🔹 Verified Remediation
* Starts Outlook with `/cleanautocompletecache` and `/recycle`, preserving the original command and arguments exactly
* Pre-check → fix → post-verify flow with structured JSON result output
* Records the launched process ID (PID) in logs and JSON diagnostics

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Clear-OutlookClientCache\`

---

# 📂 Project Structure

```text
Clear-OutlookClientCache
│
├── detect-Clear-OutlookClientCache.ps1
├── remediate-Clear-OutlookClientCache.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Clear-OutlookClientCache.ps1
```

### Purpose
Verifies whether Outlook is installed at the expected Office16 path. Strictly read-only.

### Logic
1. Test for `C:\Program Files\Microsoft Office\root\Office16\OUTLOOK.EXE`
2. Compliant when the executable is absent — there is no client cache to clean
3. Non-compliant when Outlook is found and the cleanup should run

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Clear-OutlookClientCache.ps1
```

### Purpose
Clears the Outlook autocomplete cache by starting Outlook with `/cleanautocompletecache` and `/recycle`, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `OUTLOOK.EXE` exists (missing executable exits `1`, matching legacy behavior)
2. Fix: `Start-Process -FilePath $OutlookPath -ArgumentList @('/cleanautocompletecache', '/recycle') -PassThru`
3. Post-verify: confirm the launch was recorded; an already-exited process still means the cleanup ran

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
* Runs in local SYSTEM context via Intune — no Graph permissions required.
* Assign in user context so Outlook opens interactively for the signed-in user.

### Logging
* `<SystemDrive>\IntuneLogs\Clear-OutlookClientCache\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Clear-OutlookClientCache.ps1
```

### Remediation Script
```powershell
remediate-Clear-OutlookClientCache.ps1
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
2. Detection exits with code `1` when `OUTLOOK.EXE` is found
3. Intune runs the **Remediation Script**
4. Remediation launches the Outlook cleanup switches, verifies the launch, and logs results

---

# 🛡 Operational Notes
* The autocomplete cache clear removes cached suggestion entries; users will re-accumulate suggestions as they address mail.
* `/recycle` keeps Outlook open after cleanup; an already-exited process at verification time still indicates the command ran.
* Idempotent — repeating the cleanup switches is safe.
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
