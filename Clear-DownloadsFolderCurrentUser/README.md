<div align="center">

# 🪟 Clear Downloads Folder (Current User)

**Intune Proactive Remediation package that clears the current user's Downloads folder when it is not empty.**

Detection counts the items under `$env:USERPROFILE\Downloads` and remediation deletes them recursively — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Clear Downloads Folder (Current User)** is an Intune remediation package that keeps the signed-in user's Downloads folder empty on managed devices.

The detection script counts child items under `$env:USERPROFILE\Downloads` and reports non-compliant only when content exists; a missing or already-empty folder exits compliant without touching anything. When items are found, Intune runs the paired remediation that recursively removes them and verifies the folder is empty again.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Counts items under `$env:USERPROFILE\Downloads` without modifying anything
* Treats a missing or empty Downloads folder as compliant
* Detection errors exit `2` so Intune never treats a crash as non-compliance

### 🔹 Verified Remediation
* Deletes all child content with `Remove-Item -Recurse -Force` when items are present
* Pre-check → fix → post-verify flow with structured JSON result output
* Idempotent — missing or already-empty folders exit successfully with no changes

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Clear-DownloadsFolderCurrentUser\`

---

# 📂 Project Structure

```text
Clear-DownloadsFolderCurrentUser
│
├── detect-Clear-DownloadsFolderCurrentUser.ps1
├── remediate-Clear-DownloadsFolderCurrentUser.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Clear-DownloadsFolderCurrentUser.ps1
```

### Purpose
Verifies whether the current user's Downloads folder still contains items. Strictly read-only.

### Logic
1. Resolve `$env:USERPROFILE\Downloads`; a missing folder is compliant
2. Count all child items (including hidden); an empty folder is compliant
3. Non-compliant when one or more items remain

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Clear-DownloadsFolderCurrentUser.ps1
```

### Purpose
Removes all child items from the current user's Downloads folder, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: confirm the user profile path resolves
2. Fix: `Remove-Item -Path (Join-Path $DownloadsPath '*') -Recurse -Force` against all child content
3. Post-verify: re-count items and confirm the folder is absent or empty

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
* Runs in the assigned user context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Clear-DownloadsFolderCurrentUser\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Clear-DownloadsFolderCurrentUser.ps1
```

### Remediation Script
```powershell
remediate-Clear-DownloadsFolderCurrentUser.ps1
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
2. Detection exits with code `1` when Downloads items are present
3. Intune runs the **Remediation Script**
4. Remediation deletes the content, verifies the folder is empty, and logs results

---

# 🛡 Operational Notes
* **DESTRUCTIVE:** deleted Downloads content bypasses the Recycle Bin and cannot be restored.
* Idempotent — a missing or already-empty folder exits `0` without changes.
* Runs per user context: assign to users (or devices with user context) so `$env:USERPROFILE` resolves to each target profile.
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
