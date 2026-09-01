<div align="center">

# 🌐 Disable Local Network Access Restrictions

**Intune Proactive Remediation package that applies the local-network-access experiment flag to Chrome and Edge.**

Detection verifies the flag in each browser's `Local State` JSON and remediation stops the browsers, writes the flag (with fallback variants), and relaunches them — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Disable Local Network Access Restrictions** is an Intune remediation package that keeps Chrome and Edge allowed to reach local network resources while Chromium's Local Network Access checks are being rolled out.

The detection script reads each browser's `Local State` file under `$env:LOCALAPPDATA` and requires the `local-network-access-check@3` entry in `browser.enabled_labs_experiments`. The paired remediation gracefully stops both browsers, backs up each `Local State`, injects the required flag with an older-variant fallback, restores from backup on failure, and relaunches each browser with `--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck`.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Parses Chrome and Edge `Local State` JSON without modifying anything
* Reports exactly which browser is missing the required flag
* Detection errors exit `2` so Intune never treats a crash as non-compliance

### 🔹 Verified Remediation
* Backs up each `Local State`, writes the flag with @3 → @2 variant fallback, and restores on failure
* Stops browser processes first, waits for file locks to release, then relaunches with the runtime switch
* Pre-check → fix → post-verify flow with structured JSON result output

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Disable-LocalNetworkAccessRestrictions\`

---

# 📂 Project Structure

```text
Disable-LocalNetworkAccessRestrictions
│
├── detect-Disable-LocalNetworkAccessRestrictions.ps1
├── remediate-Disable-LocalNetworkAccessRestrictions.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Disable-LocalNetworkAccessRestrictions.ps1
```

### Purpose
Verifies that Chrome and Edge both contain the required experiment flag. Strictly read-only.

### Logic
1. Read `$env:LOCALAPPDATA\Google\Chrome\User Data\Local State`
2. Read `$env:LOCALAPPDATA\Microsoft\Edge\User Data\Local State`
3. Non-compliant when either file is missing, unparseable, lacks `browser.enabled_labs_experiments`, or does not contain `local-network-access-check@3`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Disable-LocalNetworkAccessRestrictions.ps1
```

### Purpose
Applies the local-network-access flag to both browsers, using a pre-check → fix → post-verify flow with backup/restore safety and structured JSON output.

### Logic
1. Pre-check: confirm `LOCALAPPDATA` resolves; stop Chrome/Edge processes and wait up to 15 seconds for file locks
2. Fix: back up each `Local State`, rewrite `browser.enabled_labs_experiments` with `local-network-access-check@3` (@2 fallback via `-ForceVariant2`), verify per write, restore from `.bak_*` on failure; relaunch browsers with `--disable-features=LocalNetworkAccessChecks,LocalNetworkAccessCheck`
3. Post-verify: re-read both files and require an accepted flag variant in each

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
* Assign in user context so `$env:LOCALAPPDATA` resolves to each target profile.

### Logging
* `<SystemDrive>\IntuneLogs\Disable-LocalNetworkAccessRestrictions\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Disable-LocalNetworkAccessRestrictions.ps1
```

### Remediation Script
```powershell
remediate-Disable-LocalNetworkAccessRestrictions.ps1
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
2. Detection exits with code `1` when a browser is missing the required flag
3. Intune runs the **Remediation Script**
4. Remediation stops the browsers, applies the flag safely, relaunches them, verifies, and logs results

---

# 🛡 Operational Notes
* The remediation force-closes running Chrome/Edge windows — schedule assignments to avoid disrupting active users.
* A timestamped `.bak_<yyyyMMddHHmmss>` copy of each `Local State` is created before editing and restored automatically if the update fails.
* Chromium may retire or rename labs flags between versions; adjust `$RequiredFlag`/`$PrimaryFlag` in both scripts together if Google changes the variant.
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
