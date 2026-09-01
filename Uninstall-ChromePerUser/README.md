<div align="center">

# 🛡️ Uninstall Chrome Per User

**Intune Proactive Remediation package that silently removes per-user Google Chrome installations.**

Detection scans the current user's uninstall registry entries for `Google Chrome` and remediation runs the matched uninstaller silently (MSI or EXE path) until the entry disappears — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Uninstall Chrome Per User** is an Intune remediation package that cleans unwanted per-user Chrome installs off managed devices.

Chrome installed without elevation lands in `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall`, outside the reach of machine-wide MSI deployments, and often conflicts with managed browser baselines. The detection script enumerates those entries read-only, matching `DisplayName` or `DisplayName_Localized` against the blacklist; when a match exists, Intune runs the paired remediation, which parses the uninstall string and launches it silently — MSI product codes via `msiexec /x <code> /qn /norestart`, everything else via `cmd.exe` with Chrome's silent flags — then verifies the entry is gone.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Enumerates `HKCU:\...\Uninstall` subkeys — never modifies the system during detection
* Normalizes the application name from `DisplayName` or `DisplayName_Localized`
* Reports every matching blacklist entry before triggering remediation

### 🔹 Verified Remediation
* Original uninstall-string logic preserved: MSI GUIDs via `msiexec.exe`, non-MSI via `cmd.exe` with `--uninstall --force-uninstall --system-level --multi-install --chrome --silent`
* Pre-check → fix → post-verify flow with structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Uninstall-ChromePerUser\`

---

# 📂 Project Structure

```text
Uninstall-ChromePerUser
│
├── detect-Uninstall-ChromePerUser.ps1
├── remediate-Uninstall-ChromePerUser.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Uninstall-ChromePerUser.ps1
```

### Purpose
Checks whether per-user Google Chrome is registered in the current user's uninstall entries. Strictly read-only.

### Logic
1. Enumerate subkeys under `HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
2. Match normalized names against `$BlacklistApps` (`Google Chrome`)
3. Non-compliant when at least one blacklist entry exists

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Uninstall-ChromePerUser.ps1
```

### Purpose
Silently uninstalls every matched per-user Chrome entry, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the HKCU uninstall key exists
2. Fix: parse each uninstall string — MSI product code via `msiexec.exe /x ... /qn /norestart`, otherwise `cmd.exe /c "<string> --uninstall --force-uninstall --system-level --multi-install --chrome --silent"` — and require exit code `0`
3. Post-verify: re-scan the uninstall entries — compliant only when no blacklist entry remains

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

### Logged-On User
* Required — `HKCU` must point at the target profile, so deploy with "Run this script using logged-on credentials: Yes" to inspect and remove the signed-in user's installation.

### Logging
* `<SystemDrive>\IntuneLogs\Uninstall-ChromePerUser\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Uninstall-ChromePerUser.ps1
```

### Remediation Script
```powershell
remediate-Uninstall-ChromePerUser.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | Yes (required - targets HKCU of signed-in user) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` when a per-user Chrome entry is found
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation runs the silent uninstaller, verifies removal, and logs results

---

# 🛡 Operational Notes
* **Warning:** the uninstall affects the signed-in user's Chrome profile data — communicate the change before wide deployment.
* Extend `$BlacklistApps` if additional per-user applications should be removed with the same flow.
* A running Chrome instance can make the uninstaller return a non-zero exit code; schedule remediations outside active hours.
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
