<div align="center">

# 🔔 Show Reboot Toast Notification

**Intune Proactive Remediation package that reminds users to reboot machines that have been up too long.**

Detection applies the package's 7-day threshold and remediation shows a native Windows toast asking the user to restart when possible — built for enterprise fleet hygiene.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Show Reboot Toast Notification** is an Intune remediation package that nudges users toward regular reboots.

This migration preserves the original comparison exactly: detection measures the uptime of the current PowerShell process (not the OS boot time) against a 7-day threshold. Because Intune launches a fresh process on every run, the process is always younger than the threshold, so the reminder toast intentionally fires on every scheduled cycle — that is the package's always-trigger design and it is kept unchanged.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Measures current PowerShell process runtime with `Get-Process` — never modifies the system during detection
* Preserves the legacy 7-day (`$ThresholdDays`) comparison semantics exactly
* Always-trigger design documented: fresh Intune processes guarantee the toast fires on schedule

### 🔹 Verified Remediation
* Original WinRT mechanism preserved: `ToastNotificationManager` with the built-in `ToastText02` template, `PowerShell` tag/group, and a 1-minute expiration
* Pre-check → fix → post-verify flow with structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Show-RebootToastNotification\`

---

# 📂 Project Structure

```text
Show-RebootToastNotification
│
├── detect-Show-RebootToastNotification.ps1
├── remediate-Show-RebootToastNotification.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Show-RebootToastNotification.ps1
```

### Purpose
Decides whether the reboot reminder toast should run. Strictly read-only.

### Logic
1. Read the start time of the current PowerShell process
2. Compare its runtime in hours against `$ThresholdHours` (7 days)
3. Non-compliant while the runtime is below the threshold, which keeps the toast firing each cycle

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Show-RebootToastNotification.ps1
```

### Purpose
Shows the reboot reminder toast using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the WinRT `ToastNotificationManager` type loads
2. Fix: build a `ToastText02` toast ("Please Restart your Machine") and show it via the `PowerShell` notifier
3. Post-verify: confirm the dispatch call completed — user acknowledgment cannot be verified programmatically

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
* Required for visibility — toasts only render in an interactive session; deploy with "Run this script using logged-on credentials: Yes".

### Logging
* `<SystemDrive>\IntuneLogs\Show-RebootToastNotification\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Show-RebootToastNotification.ps1
```

### Remediation Script
```powershell
remediate-Show-RebootToastNotification.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | Yes (required - toast needs user context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` so the reminder fires on schedule
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation dispatches the toast, verifies dispatch, and logs results

---

# 🛡 Operational Notes
* The process-uptime comparison is a legacy quirk preserved on purpose; treat this package as a scheduled reminder, not an actual uptime meter.
* Adjust `$ThresholdDays`, `$ToastTitle`, and `$ToastText` at the top of the scripts if you want different wording or cadence.
* Verification is honest by design: success means the toast was dispatched, not that the user rebooted.
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
