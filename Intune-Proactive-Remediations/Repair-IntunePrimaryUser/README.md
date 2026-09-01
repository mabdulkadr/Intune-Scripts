<div align="center">

# ☁️ Intune Primary User Update

**Intune Proactive Remediation package that keeps every Intune device assigned to its active user as primary user.**

Detection queries Microsoft Graph for the device's primary users and remediation assigns the current console user via the `managedDevices(id)/users/$ref` endpoint — restoring user-device affiliation for app targeting and user affinity.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Primary User Update** is an Intune remediation package that repairs missing primary-user assignments in Microsoft Intune.

The primary user drives Intune user affinity: self-service portal targeting, application assignment scoping, and inventory correlation all depend on it. Devices provisioned without a signed-in enrollment user (for example Windows Autopilot self-deploying or Provisioning packages) end up with none. Detection reads the `managedDevices(id)/users` navigation via Graph app-only auth; when no primary user exists, the paired remediation detects the active console session, resolves the user by UPN, POSTs the `$ref` assignment, and verifies it.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Locates the device in `deviceManagement/managedDevices` by name (v1.0) and reads primary users (beta)
* Never modifies assignments during detection
* Reports non-compliance when no primary user is assigned

### 🔹 Verified Remediation
* Detects the active console session (`query user`), maps SAM to UPN, assigns via Graph with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics; idempotent when already assigned
* Preserves the legacy app-only client-credentials authentication pattern

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Repair-IntunePrimaryUser\`

---

# 📂 Project Structure

```text
Repair-IntunePrimaryUser
│
├── detect-Repair-IntunePrimaryUser.ps1
├── remediate-Repair-IntunePrimaryUser.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Repair-IntunePrimaryUser.ps1
```

### Purpose
Reports whether this device already has a primary user. Strictly read-only against Graph.

### Logic
1. Acquire a Graph token (client credentials; scope `.default`)
2. Find the managed device by `$env:COMPUTERNAME`, then read `managedDevices(id)/users`
3. Compliant when at least one primary user exists; non-compliant when none is assigned or the device is not found; Graph failures exit code `2`

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Repair-IntunePrimaryUser.ps1
```

### Purpose
Assigns the active console user as the device primary user, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: validate Graph credentials; exit `0` when no active console session exists
2. Fix: acquire token, resolve device and user by UPN, skip if already assigned, otherwise POST `users/$ref`
3. Post-verify: re-read the primary-user list and confirm the target user's ID is present

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success (assignment verified, or no action required) |
| 1    | Failure (verification failed after applying) |
| 2    | Script error |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Runs in local SYSTEM context via Intune.
* Microsoft Graph app-only credentials configured in CONFIGURATION (`TenantId`, `ClientId`, `ClientSecret`; remediation also needs `DefaultUpnSuffix`). Required scopes on the app registration: `DeviceManagementManagedDevices.Read.All`, `DeviceManagementManagedDevices.ReadWrite.All`, `User.Read.All`.

### Logging
* `<SystemDrive>\IntuneLogs\Repair-IntunePrimaryUser\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Repair-IntunePrimaryUser.ps1
```

### Remediation Script
```powershell
remediate-Repair-IntunePrimaryUser.ps1
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
2. Detection exits with code `1` when the device has no primary user
3. Intune runs the **Remediation Script**
4. Remediation assigns the active console user, verifies the assignment, and logs results

---

# 🛡 Operational Notes
* Changing the primary user affects user-device affiliation in Intune — application/user targeting, Self-service portal grouping, and user-affinity reporting will follow the new owner.
* Fill in `TenantId`, `ClientId`, `ClientSecret`, and (in remediation) `DefaultUpnSuffix` before deployment; empty credentials intentionally fail fast with exit `2`.
* The SAM-to-UPN mapping assumes a single uniform UPN suffix; hybrid environments with multiple suffixes need directory-based resolution instead.
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

