<div align="center">

# 📦 Reinstall Company Portal via Winget

**Reinstall Company Portal via Winget**

Repairs a broken Microsoft Company Portal installation by uninstalling and reinstalling it with winget — for IT support and Intune enrollment troubleshooting.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [License](#-license)

</div>

---

# 📖 Overview

**Repair-CompanyPortal** is a PowerShell script that gives the Microsoft Company Portal a clean reinstall in one pass.

It verifies the console is elevated, resolves the winget executable directly from the WindowsApps App Installer package, checks whether Company Portal is installed via `winget list`, uninstalls it when present, and installs it fresh from the Microsoft Store source with automatic agreement acceptance. Purely local — no Graph calls, no tenant data.

---

# ✨ Features

* Elevation guard: refuses to run without administrator rights
* Robust winget resolution from `Microsoft.DesktopAppInstaller` (opens the Store page automatically when missing)
* Install-state detection via exact-name `winget list` query
* Clean uninstall → fresh install flow from the `msstore` source
* Timestamped, level-colored logging to `C:\ProgramData\Repair-CompanyPortal\Logs\`

---

# 📂 Project Structure

```text
Repair-CompanyPortal-Winget
│
 ├── Repair-CompanyPortal.ps1
 └── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Repair-CompanyPortal.ps1
```

### Typical Repair Scenario
```powershell
# From an elevated console when Company Portal is corrupted or blocks enrollment:
.\Repair-CompanyPortal.ps1
```
The script removes any existing Company Portal package, then installs the current Store version.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| None | — | — | — | The script is fully self-contained |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Reinstall flow completed |
| 1    | Missing elevation, winget not found, or a failed step |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* Elevated (Administrator) console — required for winget package uninstall/install of Company Portal.

### Logging
* `C:\ProgramData\Repair-CompanyPortal\Logs\`

---

# 🛡 Operational Notes
* Requires the App Installer (winget); its Microsoft Store product page opens automatically when the executable cannot be resolved.
* Installation uses the `msstore` source with `--accept-package-agreements --accept-source-agreements`.
* The tool intentionally modifies the system: it removes and reinstalls the Company Portal package.
* Purely local execution context — no Microsoft Graph calls and no Intune permissions needed.
* Failure paths exit with code 1 so automation and Proactive Remediation wrappers can react correctly.

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
