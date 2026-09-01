<div align="center">

# 🪟 Set OneDrive Folder Offline Availability

**Intune Proactive Remediation package that pins the user's OneDrive folder and its contents for offline use.**

Detection reads the pinned-state attributes of the `OneDrive - <Company>\Desktop` folder with `attrib.exe` and remediation applies `-U +P` across the folder tree so files stay available offline — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Set OneDrive Folder Offline Availability** is an Intune remediation package that keeps the configured OneDrive for Microsoft 365 folder always available offline.

Files synced by OneDrive are cloud-only by default, which breaks offline work and some legacy applications. The detection script builds the expected path (`OneDrive - scloud\Desktop` under the current user profile), reads its attributes via `attrib.exe`, and requires the normalized output to contain the `R/P` pinned pattern. When the pin state is missing — or the folder does not exist yet — Intune runs the paired remediation that pins the root tree and every child item.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Builds the target path from the current user profile: `OneDrive - scloud\Desktop`
* Reads attributes with a single `attrib.exe` call — never modifies the system during detection
* Reports a missing folder or missing pin state before triggering remediation

### 🔹 Verified Remediation
* Pins the root tree with `attrib.exe -U +P /s /d`, then `-U +P` per child item (original mechanism preserved)
* Pre-check → fix → post-verify flow with structured JSON result output for Intune diagnostics
* Idempotent — safe to run repeatedly on the same device

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Set-OneDriveFolderOfflineAvailability\`

---

# 📂 Project Structure

```text
Set-OneDriveFolderOfflineAvailability
│
├── detect-Set-OneDriveFolderOfflineAvailability.ps1
├── remediate-Set-OneDriveFolderOfflineAvailability.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Set-OneDriveFolderOfflineAvailability.ps1
```

### Purpose
Verifies that the OneDrive folder appears to be pinned for offline use. Strictly read-only.

### Logic
1. Build the expected OneDrive business folder path from the current user profile
2. Run `attrib.exe` against the path, normalize the output, and require the `R/P` pattern
3. Non-compliant when the folder is missing or not pinned

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Set-OneDriveFolderOfflineAvailability.ps1
```

### Purpose
Pins the OneDrive folder and all of its contents for offline availability, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the target OneDrive folder exists
2. Fix: `attrib.exe -U +P /s /d` on the root, then `attrib.exe -U +P` on each child item recursively
3. Post-verify: re-run the attribute check and compare against the compliant pin state

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
* Required — the target path is derived from `$env:USERPROFILE`, so both scripts must run under the signed-in user to inspect and pin the correct OneDrive folder.

### Logging
* `<SystemDrive>\IntuneLogs\Set-OneDriveFolderOfflineAvailability\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Set-OneDriveFolderOfflineAvailability.ps1
```

### Remediation Script
```powershell
remediate-Set-OneDriveFolderOfflineAvailability.ps1
```

### Recommended Settings
| Setting | Value |
| ------- | ----- |
| Run script in 64-bit PowerShell | Yes |
| Run this script using logged-on credentials | Yes (required - user context) |
| Enforce script signature check | No |

---

# 🔧 Typical Workflow
1. Intune runs the **Detection Script**
2. Detection exits with code `1` when the folder is missing or not pinned
3. If non-compliant, Intune runs the **Remediation Script**
4. Remediation pins the folder tree, verifies it, and logs results

---

# 🛡 Operational Notes
* Idempotent by design — devices already compliant exit `0` without changes.
* Adjust `$CompanyName` and `$ODFolder` in both scripts if your tenant uses a different OneDrive folder layout.
* Pinning large folder trees can trigger OneDrive downloads; schedule accordingly.
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
