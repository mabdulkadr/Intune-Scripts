<div align="center">

# 🧰 Uninstall Installed Application

**Intune Proactive Remediation package that uninstalls blacklisted applications from managed devices.**

Detection compares installed display names against a configurable blacklist array and remediation silently uninstalls every match using its own registry uninstall string — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Uninstall Installed Application** is an Intune remediation package that removes unwanted applications across managed devices based on a configurable blacklist.

The scripts query the standard 64-bit and 32-bit HKLM uninstall registry locations and compare discovered display names (falling back to the localized name when empty) against the `$BlacklistApps` array. Detection is strictly read-only; when one or more blacklist entries are found, Intune runs the paired remediation, which launches the matching silent uninstall for each application — `msiexec.exe /x {GUID} /qn /norestart` for MSI products, or the vendor command wrapped in `cmd.exe` with `/S` appended — then verifies no blacklisted entry remains.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Queries both HKLM uninstall registry views and matches against `$BlacklistApps`
* Reports every blacklisted application with its `UninstallString`
* Never modifies the system during detection

### 🔹 Verified Remediation
* Per-application uninstall with failure tracking and pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — a device without blacklisted applications exits successfully without changes

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Uninstall-InstalledApplication\`

---

# 📂 Project Structure

```text
Uninstall-InstalledApplication
│
├── detect-Uninstall-InstalledApplication.ps1
├── remediate-Uninstall-InstalledApplication.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Uninstall-InstalledApplication.ps1
```

### Purpose
Verifies that none of the configured blacklisted applications are installed. Strictly read-only.

### Logic
1. Query the standard 64-bit and 32-bit HKLM uninstall registry locations
2. Compare each display name against the `$BlacklistApps` array
3. Compliant when nothing matches; non-compliant with one reason per matched application

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Uninstall-InstalledApplication.ps1
```

### Purpose
Silently uninstalls every detected blacklisted application, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the uninstall registry keys are readable and resolve all blacklist matches
2. Fix: for each match, launch its silent uninstaller (`msiexec.exe /x {GUID} /qn /norestart`, or `cmd.exe /c "<uninstall string> /S"`) and wait; missing uninstall strings count as per-target failures
3. Post-verify: re-query the registry and confirm no blacklisted application remains

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
* `<SystemDrive>\IntuneLogs\Uninstall-InstalledApplication\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Uninstall-InstalledApplication.ps1
```

### Remediation Script
```powershell
remediate-Uninstall-InstalledApplication.ps1
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
2. Detection exits with code `1` when a blacklisted application is found
3. Intune runs the **Remediation Script**
4. Remediation uninstalls each match, verifies the result, and logs outcomes

---

# 🛡 Operational Notes
* Edit `$BlacklistApps` in both scripts to control which display names are targeted; matching is exact and case-insensitive.
* Vendor uninstallers vary in quality — some exit `0` before finishing asynchronously; review logs when verification reports leftovers.
* Non-MSI applications are invoked via `cmd.exe /c "<command> /S"`, which assumes the vendor installer supports the `/S` silent flag.
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
