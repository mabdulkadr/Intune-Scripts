<div align="center">

# 🛡️ Invoke Logoff Current User

**Intune Proactive Remediation package that warns and signs out the current interactive user.**

Detection is an always-trigger detector that reports non-compliant on every run — remediation then shows a save-your-work warning, waits through a 60-second countdown, and issues `shutdown.exe /l` to sign out the current session.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Invoke Logoff Current User** is an Intune remediation package for controlled, user-friendly session sign-outs.

This package intentionally has no real compliance condition: the detection script is an always-trigger detector (preserved by design from the legacy pair) that exits `1` on every run. The paired remediation displays a WPF warning dialog telling the user to save their work, waits the configured 60 seconds, and then logs off via `shutdown.exe /l` — a graceful sign-out that closes applications cleanly rather than forcing them.

---

# ✨ Core Features

### 🔹 Always-Trigger Detection
* Deliberately evaluates nothing — exits `1` on every run by design
* Documents its always-run intent in output and logs for operators
* Keeps the pair predictable: every detection cycle ends in a logoff flow

### 🔹 Verified Remediation
* Modal warning dialog (WPF PresentationFramework) before any action
* 60-second countdown handled in-script (`shutdown.exe /l` supports no delay switch)
* Verifies shutdown.exe accepted the request; emits structured JSON output
* Pre-check confirms shutdown.exe exists before anything happens

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Invoke-LogoffCurrentUser\`

---

# 📂 Project Structure

```text
Invoke-LogoffCurrentUser
│
├── detect-Invoke-LogoffCurrentUser.ps1
├── remediate-Invoke-LogoffCurrentUser.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Invoke-LogoffCurrentUser.ps1
```

### Purpose
Always triggers the paired remediation. Strictly read-only — it performs no system evaluation.

### Logic
1. Report one fixed condition: "a current-user logoff is requested"
2. Exit `1` on every run so Intune invokes the remediation

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Invoke-LogoffCurrentUser.ps1
```

### Purpose
Warns the current user, waits through the countdown, and initiates the sign-out, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `shutdown.exe` exists and record the execution identity
2. Fix: show the warning dialog, wait 60 seconds, run `shutdown.exe /l`
3. Post-verify: require an accepted shutdown.exe request (exit code 0)

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
* Intended for an interactive user session via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Invoke-LogoffCurrentUser\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Invoke-LogoffCurrentUser.ps1
```

### Remediation Script
```powershell
remediate-Invoke-LogoffCurrentUser.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | No (SYSTEM context) |
| Enforce script signature check | No |

> Assign with care: the remediation must reach the interactive user session for the warning dialog and logoff to be meaningful.

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` on every run (always-trigger design)
3. Intune always runs the **Remediation Script**
4. Remediation warns the user, counts down, signs out, and logs results

---

# 🛡 Operational Notes
* **Forced logoff disrupts the signed-in user** — unsaved work is at risk once the warning appears; tune `$TimeoutSeconds` and assignment scope deliberately.
* Run this pair in the logged-on user context so the WPF warning dialog is visible; in SYSTEM context the flow still works but no dialog is shown.
* `shutdown.exe /l` performs a graceful sign-out (no `/f` force switch), so applications can still prompt to save.
* An accepted shutdown.exe request is the guaranteed outcome; session teardown completes asynchronously afterwards.
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
