<div align="center">

# ⚙️ Update Winget Packages

**Intune Proactive Remediation package that keeps Winget-managed applications up to date.**

Detection asks the Winget client for pending upgrades and remediation runs a silent `winget upgrade --all` with source and package agreements accepted — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Update Winget Packages** is an Intune remediation package that closes the patching gap left by MSI/EXE line-of-business deployments: every application the Winget client manages gets upgraded automatically.

The detection script resolves the Winget executable (App Installer package, WindowsApps fallback paths, PATH, or the per-user execution shim), runs `winget upgrade --accept-source-agreements`, and classifies the output rows into a pending-upgrade snapshot. When upgrades are pending, Intune runs the paired remediation, which executes `winget upgrade --all --force --silent` with both agreements accepted, logs every output line, and verifies the run through Winget's own exit code.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Resolves the Winget client without assuming it is on `PATH`
* Parses `winget upgrade` output into package rows, header/footer noise filtered out
* Never modifies the system during detection

### 🔹 Verified Remediation
* Silent full upgrade (`--all --force --silent`) with package and source agreements accepted
* Full output capture to the log plus pre-check → fix → post-verify flow with JSON result output
* Idempotent — no pending upgrades means nothing to do

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Update-WingetPackages\`

---

# 📂 Project Structure

```text
Update-WingetPackages
│
├── detect-Update-WingetPackages.ps1
├── remediate-Update-WingetPackages.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Update-WingetPackages.ps1
```

### Purpose
Verifies whether the Winget client reports pending package upgrades. Strictly read-only.

### Logic
1. Resolve the Winget executable; if absent, report compliant (nothing can be evaluated)
2. Run `winget upgrade --accept-source-agreements` and classify the returned rows
3. Compliant when no upgrades are reported or Winget says none are available; non-compliant otherwise

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Update-WingetPackages.ps1
```

### Purpose
Upgrades all packages that Winget considers eligible, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: resolve the Winget client; when absent there is nothing to remediate (reported as success)
2. Fix: run `winget upgrade --all --force --silent --accept-package-agreements --accept-source-agreements`, logging every output line
3. Post-verify: confirm the Winget run exited `0`; any other code fails verification

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

### Winget
* The **Winget client (App Installer)** must be present on the device; both scripts treat its absence as "nothing to do".

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Update-WingetPackages\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Update-WingetPackages.ps1
```

### Remediation Script
```powershell
remediate-Update-WingetPackages.ps1
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
2. Detection exits with code `1` when Winget reports pending upgrades
3. Intune runs the **Remediation Script**
4. Remediation upgrades all eligible packages silently and verifies the run

---

# 🛡 Operational Notes
* **Winget upgrades can restart or interrupt running applications** — schedule remediations outside business hours where possible.
* Some packages never appear in `winget upgrade` (portable EXEs with unknown versions, MS Store-managed apps); those stay on whatever update channel they use natively.
* A non-zero Winget exit code fails the run even though some packages may have upgraded successfully — check the log for the failing package.
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
