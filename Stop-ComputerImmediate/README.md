<div align="center">

# 🛡️ Stop Computer Immediate

**Intune Proactive Remediation package that shows a restart notice and schedules an immediate machine restart.**

Detection intentionally reports non-compliant on every run and remediation displays a notice dialog then schedules a restart with `shutdown.exe /r /t 60 /d p:0:0` — built for enterprise fleet maintenance windows.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Stop Computer Immediate** is an Intune remediation package that forces a scheduled restart on managed devices.

This is an always-trigger package by design: detection evaluates nothing and exits `1` on every run, so Intune invokes the remediation each cycle. The remediation shows a brief WPF restart notice (best-effort — it renders only in interactive sessions), then launches `shutdown.exe` with the original flags `/r /t 60 /d p:0:0`, giving users a 60-second grace period before Windows performs the restart.

---

# ✨ Core Features

### 🔹 Always-Trigger Detection
* No device state is evaluated; non-compliant is returned by design every cycle
* Read-only — the detector never touches the system

### 🔹 Verified Remediation
* Original mechanism preserved: hidden `shutdown.exe /r /t 60 /d p:0:0` via `Start-Process`
* Pre-check → fix → post-verify flow with structured JSON result output for Intune diagnostics
* Graceful notice handling: message-box failures are logged as warnings and never block the restart

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Stop-ComputerImmediate\`

---

# 📂 Project Structure

```text
Stop-ComputerImmediate
│
├── detect-Stop-ComputerImmediate.ps1
├── remediate-Stop-ComputerImmediate.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Stop-ComputerImmediate.ps1
```

### Purpose
Always returns a non-zero result so the paired remediation runs every cycle. Strictly read-only.

### Logic
1. Initialize logging and banner
2. Report the single intentional condition: "remediation is intentionally triggered on every run"
3. Exit `1` unconditionally (exit `2` only for unexpected script errors)

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Stop-ComputerImmediate.ps1
```

### Purpose
Shows the restart notice and schedules a restart in 60 seconds, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm `%SystemRoot%\System32\shutdown.exe` exists
2. Fix: show the WPF notice (best-effort), then launch `shutdown.exe /r /t 60 /d p:0:0` hidden and require exit code `0`
3. Post-verify: confirm shutdown accepted and scheduled the restart — actual completion cannot be verified because the machine reboots within the timeout

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
* `<SystemDrive>\IntuneLogs\Stop-ComputerImmediate\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Stop-ComputerImmediate.ps1
```

### Remediation Script
```powershell
remediate-Stop-ComputerImmediate.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | Yes recommended - the notice dialog needs an interactive session |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection always exits with code `1` by design
3. Intune runs the **Remediation Script**
4. Remediation shows the notice, schedules the restart, verifies scheduling, and logs results

---

# 🛡 Operational Notes
* **Warning:** this package force-schedules a restart without saving work — assign it only to carefully scoped device groups and maintenance schedules.
* The 60-second timeout gives users a short grace window; unsaved work follows the normal Windows shutdown flow.
* In SYSTEM context (session 0) the notice dialog cannot render; the package logs a warning and proceeds with the restart.
* Users can abort a pending restart manually with `shutdown /a` before the timeout elapses.

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
