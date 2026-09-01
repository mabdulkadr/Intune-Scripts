<div align="center">

# 🛡️ Unpin Microsoft Store

**Intune Proactive Remediation package that removes the Microsoft Store icon from the taskbar.**

Detection inspects the AppsFolder shell namespace for an available "Unpin from taskbar" verb on the Store app and remediation invokes that verb to remove the pin — built for enterprise fleet baselines.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#-intune-deployment)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Deployment](#-intune-deployment) • [Workflow](#-typical-workflow) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Unpin Microsoft Store** is an Intune remediation package that keeps the Microsoft Store off the managed taskbar.

The scripts automate the same action a user performs by hand: they resolve the Store item in the `shell:::{4234d49b-0245-4df3-b780-3893943456e1}` AppsFolder namespace, enumerate its shell verbs, and use the "Unpin from taskbar" verb as the compliance signal. Detection is strictly read-only; remediation invokes the verb and then verifies the verb is no longer offered, which means the icon is no longer pinned.

---

# ✨ Core Features

### 🔹 Read-Only Detection
* Resolves the Microsoft Store item by exact display name and enumerates its shell verbs
* Treats an available "Unpin from taskbar" verb as evidence the Store is pinned
* Never modifies the system during detection

### 🔹 Verified Remediation
* Invokes the shell unpin verb with pre-check → fix → post-verify flow
* Emits structured JSON result output for Intune diagnostics
* Idempotent — devices where nothing is pinned exit successfully without changes

### 🔹 Enterprise Logging
* Timestamped, level-colored log lines (`INFO` / `SUCCESS` / `WARNING` / `ERROR` / `DEBUG`)
* Written to `<SystemDrive>\IntuneLogs\Unpin-MicrosoftStore\`

---

# 📂 Project Structure

```text
Unpin-MicrosoftStore
│
├── detect-Unpin-MicrosoftStore.ps1
├── remediate-Unpin-MicrosoftStore.ps1
└── README.md
```

---

# 📜 Scripts Included

## 🔎 Detection Script

**File**
```powershell
detect-Unpin-MicrosoftStore.ps1
```

### Purpose
Verifies that Microsoft Store does not expose an Unpin-from-taskbar action. Strictly read-only.

### Logic
1. Open the AppsFolder shell namespace via `Shell.Application`
2. Locate the `Microsoft Store` item by exact display name and enumerate its verbs
3. Compliant when the item is absent or offers no unpin verb; non-compliant when it does

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Compliant (no remediation needed) |
| 1    | Non-compliant (triggers remediation) |
| 2    | Script error |

## 🛠 Remediation Script

**File**
```powershell
remediate-Unpin-MicrosoftStore.ps1
```

### Purpose
Invokes the shell verb that removes Microsoft Store from the taskbar, using a pre-check → fix → post-verify flow with structured JSON output.

### Logic
1. Pre-check: open the shell namespace and resolve the Store item with the `*store*` wildcard pattern
2. Fix: find the English "Unpin from taskbar" verb and call `DoIt()` on it
3. Post-verify: re-inspect the verbs and confirm the unpin action is gone

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
* The shell namespace mirrors the interactive user's taskbar; user-context execution gives the most accurate results.

### Logging
* `<SystemDrive>\IntuneLogs\Unpin-MicrosoftStore\`

---

# 🧭 Intune Deployment

### Detection Script
```powershell
detect-Unpin-MicrosoftStore.ps1
```

### Remediation Script
```powershell
remediate-Unpin-MicrosoftStore.ps1
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
2. Detection exits with code `1` when the Store exposes an unpin taskbar verb
3. Intune runs the **Remediation Script**
4. Remediation invokes the unpin verb, verifies it is gone, and logs results

---

# 🛡 Operational Notes
* Verb names are localized by Windows; this package matches the English "Unpin from taskbar" verb only, so deploy to English-language devices or extend matching deliberately.
* Users can re-pin the Store at any time; keep the remediation assigned to recur if the baseline requires it.
* Shell automation requires an interactive session for full fidelity; SYSTEM-context runs may not see every per-user pin state.
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
