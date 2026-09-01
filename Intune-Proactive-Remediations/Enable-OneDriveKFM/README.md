<div align="center">

# ☁️ Enable OneDrive Known Folder Move

**Intune Proactive Remediation package that enforces OneDrive Known Folder Move (KFM) silent opt-in.**

Detection verifies the KFM policy registry values and remediation writes them so Desktop, Documents and Pictures redirect to OneDrive at next sign-in.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Enable OneDrive KFM** ensures every managed device has the OneDrive Known Folder Move policy configured for the expected Entra tenant.

The detection script reads `HKLM:\SOFTWARE\Policies\Microsoft\OneDrive\KFMSilentOptIn` and related values. When the policy is missing or points to a different tenant, Intune runs the paired remediation that writes the correct keys. Devices without the OneDrive sync client are reported compliant with a note since KFM cannot apply there.

> **Important:** set `$ExpectedTenantId` to your Entra tenant ID in both scripts before deploying.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Reads `KFMSilentOptIn`, `KFMSilentOptInDesktop`, `KFMSilentOptInDocuments`, `KFMSilentOptInPictures` from the OneDrive policy key
* Verifies the OneDrive sync client is installed
* Never modifies the system during detection

### 🔹 Verified Remediation
* Writes the KFM policy keys for the expected tenant (pre-check → fix → post-verify)
* Emits structured JSON result output
* Idempotent — safe to run repeatedly

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR`)
* Written to `<SystemDrive>\IntuneLogs\Enable-OneDriveKFM\`

---

# 📂 Project Structure

```text
Enable-OneDriveKFM
│
├── detect-Enable-OneDriveKFM.ps1
├── remediate-Enable-OneDriveKFM.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Enable-OneDriveKFM.ps1
```

### Purpose
Verifies KFM is configured for the expected tenant. Strictly read-only.

### Logic
1. Confirm OneDrive sync client is installed
2. Read `KFMSilentOptIn` and compare to `$ExpectedTenantId`
3. Compliant when value matches; otherwise non-compliant

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Compliant (KFM configured or not applicable) |
| 1 | Non-compliant (triggers remediation) |
| 2 | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Enable-OneDriveKFM.ps1
```

### Purpose
Writes the KFM silent opt-in policy keys for the expected tenant with pre-check → fix → post-verify.

### Logic
1. Pre-check: validate parent registry path exists (create if missing)
2. Fix: `Set-ItemProperty` writes `KFMSilentOptIn` and folder-specific values
3. Post-verify: read values back and emit JSON result

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success (fix applied and verified) |
| 1 | Failure (verification failed) |
| 2 | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune — no Graph permissions required.

### Logging
* `<SystemDrive>\IntuneLogs\Enable-OneDriveKFM\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Enable-OneDriveKFM.ps1
```

### Remediation Script
```powershell
remediate-Enable-OneDriveKFM.ps1
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
2. Detection exits `1` when KFM is not configured for the expected tenant
3. Intune runs the **Remediation Script**
4. Remediation writes the policy, verifies it, and logs results
5. KFM takes effect at the next OneDrive sign-in (Desktop/Documents/Pictures move to OneDrive)

---

# 🛡 Operational Notes
* Set `$ExpectedTenantId` in **both** scripts before upload — default placeholder will exit `2`.
* Test on a pilot group; KFM moves user folders and should be validated with representative profiles.
* Devices without OneDrive are treated as compliant (nothing to enforce).
* Detection errors exit `2` so Intune never treats a crash as non-compliance.

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
