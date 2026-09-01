<div align="center">

# 🪟 Clear Stale User Profiles

**Intune Proactive Remediation package that removes local user profiles unused for more than 30 days.**

Detection queries `Win32_UserProfile` via CIM for profiles older than the threshold and remediation removes them with `Remove-CimInstance` — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Clear Stale User Profiles** is an Intune remediation package that reclaims disk space on shared devices by removing abandoned local user profiles.

The detection script enumerates `Win32_UserProfile` and flags local, non-special, not-loaded profiles whose `LastUseTime` is older than 30 days, excluding Default/Public profile folders. When stale profiles are found, Intune runs the paired remediation that deletes each profile through the CIM profile provider — removing both the folder tree and its registry hive in a supported way.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries `Win32_UserProfile` via CIM without modifying anything
* Applies the legacy exclusion filters: special, loaded, pathless, SID-less, LastUseTime-less, and Default/Public folders
* Detection errors exit `2` so Intune never treats a crash as non-compliance

### 🔹 Verified Remediation
* Removes each stale profile with `Remove-CimInstance` (folder + registry hive, per-profile failure tracking)
* Pre-check → per-profile fix → post-verify flow with structured JSON result output
* Re-runs the same query post-fix; any remaining stale profile fails verification

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Per-profile detail lines with path, SID, and last-use time
* Written to `<SystemDrive>\IntuneLogs\Clear-StaleUserProfiles\`

---

# 📂 Project Structure

```text
Clear-StaleUserProfiles
│
├── detect-Clear-StaleUserProfiles.ps1
├── remediate-Clear-StaleUserProfiles.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Clear-StaleUserProfiles.ps1
```

### Purpose
Detects local user profiles whose `LastUseTime` is older than 30 days. Strictly read-only.

### Logic
1. Query all `Win32_UserProfile` instances via CIM
2. Filter to stale candidates using the exclusion rules (special/system, loaded, invalid path/SID, missing LastUseTime, Default/Public folders)
3. Non-compliant when one or more stale profiles remain

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Clear-StaleUserProfiles.ps1
```

### Purpose
Removes stale local user profiles with the same filters as detection, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the `Win32_UserProfile` CIM class is reachable
2. Fix: `Remove-CimInstance -InputObject $staleProfile -ErrorAction Stop` for every qualifying profile
3. Post-verify: re-run the stale-profile query and confirm nothing qualifies anymore

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

### Logging
* `<SystemDrive>\IntuneLogs\Clear-StaleUserProfiles\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Clear-StaleUserProfiles.ps1
```

### Remediation Script
```powershell
remediate-Clear-StaleUserProfiles.ps1
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
2. Detection exits with code `1` when stale profiles older than 30 days are found
3. Intune runs the **Remediation Script**
4. Remediation removes each stale profile via CIM, verifies none remain, and logs results

---

# 🛡 Operational Notes
* **DESTRUCTIVE AND IRREVERSIBLE:** removed profiles lose their documents, desktop items, and user data permanently — validate assignment scope carefully.
* Currently loaded and special/system profiles are never touched; only truly idle profiles qualify.
* Adjust `$StaleAfterDays` in both scripts together if a different threshold is required.
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
