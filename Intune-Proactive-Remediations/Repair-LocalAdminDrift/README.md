<div align="center">

# 🔐 Repair Local Admin Drift

**Intune Proactive Remediation package that removes unauthorized members from the local Administrators group.**

Detection enumerates the group via ADSI and remediation removes anyone not on the allowlist or well-known SID set.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Repair Local Admin Drift** keeps the local `Administrators` group (`S-1-5-32-544`) clean by comparing every member against an allowlist.

Allowed members include the built-in Administrator (RID 500), Entra ID Joined Device Local Administrator role SIDs (`S-1-12-1-…`), Domain/Enterprise Admins on hybrid-joined devices, and the configurable `$AllowedNames` list (keep it in sync between detection and remediation). Any other member is flagged as unauthorized.

Detection is read-only via ADSI (handles orphaned SIDs that break `Get-LocalGroupMember`); remediation removes unauthorized members and verifies with structured JSON output.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* ADSI enumeration of `S-1-5-32-544`
* Resolves SID + name + AdsPath per member; tolerates orphaned entries
* Never modifies membership during detection

### 🔹 Verified Remediation
* `Remove-LocalGroupMember` for unauthorized members only (pre-check → fix → post-verify)
* Emits structured JSON result
* Idempotent — already-compliant devices exit `0` without changes

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines
* Written to `<SystemDrive>\IntuneLogs\Repair-LocalAdminDrift\` (legacy `local-admin-drift`)

---

# 📂 Project Structure

```text
Repair-LocalAdminDrift
│
├── detect-Repair-LocalAdminDrift.ps1
├── remediate-Repair-LocalAdminDrift.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-LocalAdminDrift.ps1
```

### Purpose
Reports whether the local Administrators group contains only approved members. Read-only.

### Logic
1. `Get-AdministratorsGroupMember` via ADSI
2. `Test-AllowedMember` checks RID 500, `S-1-12-1-*`, `-512`/`-519`, and `$AllowedNames`
3. Compliant when no unauthorized members; non-compliant otherwise

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Compliant (only approved members present) |
| 1 | Non-compliant (triggers remediation) |
| 2 | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-LocalAdminDrift.ps1
```

### Purpose
Removes unauthorized members from the local Administrators group.

### Logic
1. Pre-check: enumerate and filter unauthorized members (same logic as detection)
2. Fix: `Remove-LocalGroupMember` per unauthorized entry
3. Post-verify: re-enumerate and confirm compliance; emit JSON

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success (all unauthorized members removed and verified) |
| 1 | Failure (members remain after remediation) |
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
* `<SystemDrive>\IntuneLogs\Repair-LocalAdminDrift\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-LocalAdminDrift.ps1
```

### Remediation Script
```powershell
remediate-Repair-LocalAdminDrift.ps1
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
2. Detection exits `1` when unauthorized members exist
3. Intune runs the **Remediation Script**
4. Remediation removes them, verifies, and logs JSON result

---

# 🛡 Operational Notes
* Keep `$AllowedNames` identical in both scripts — add your LAPS-managed admin account name there.
* Built-in Administrator (RID 500) and Entra device admin role SIDs are always allowed.
* Uses ADSI because `Get-LocalGroupMember` fails on orphaned SIDs.
* Test on a pilot group; removing the wrong account can lock out local support.
* Detection errors exit `2` so a crash is never treated as non-compliance.

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
