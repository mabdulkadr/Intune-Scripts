<div align="center">

# 🛡️ Intune-Custom-Compliance

**Intune custom compliance script library that reports device state back to Microsoft Intune.**

PowerShell discovery scripts emit JSON evaluated by Intune custom compliance policies so administrators can enforce application presence, version, and other device conditions.

[![Intune](https://img.shields.io/badge/Intune-Custom%20Compliance-10B981?style=for-the-badge)](#%EF%B8%8F-requirements)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Projects](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Intune-Custom-Compliance** contains PowerShell-based **Microsoft Intune custom compliance** content.

Unlike proactive remediations, the projects in this area are designed to **report state** back to Intune rather than change it. Most packages return JSON that matches a companion compliance rule file so Intune can evaluate application presence, application version, or other device conditions.

Each subfolder is documented separately and usually contains:

* A PowerShell detection or reporting script
* A JSON compliance rule when applicable
* A project-specific `README.md`

---

# ✨ Core Features

### 🔹 Intune-Compatible JSON Output
The scripts in this area are built around the output format expected by **Intune custom compliance policies**.

### 🔹 Registry and App State Reporting
Most packages inspect installed software or device state through local Windows data sources such as uninstall registry entries.

### 🔹 Project-Level Packaging
Each compliance scenario is isolated in its own folder so the script, rule file, and documentation stay together.

---

# 📂 Project Structure

```text
Intune-Custom-Compliance
│
├── Get-AppPresenceCompliance
│   ├── Get-AppPresenceCompliance.ps1
│   ├── Get-AppPresenceCompliance.json
│   └── README.md
│
├── Get-AppVersionCompliance
│   └── README.md
│
├── CustomCompliancePolicyGeneratorGUI
│   └── README.md
│
└── README.md
```

---

# 📜 Scripts Included

## 📦 Compliance Packages

This folder currently contains:

* `Get-AppPresenceCompliance` — reports whether configured applications are installed (`true`/`false` per app)
* `Get-AppVersionCompliance` — reports installed application versions for minimum-version evaluation
* `CustomCompliancePolicyGeneratorGUI` — GUI generator that produces detection scripts and JSON rules for multiple applications

Each package has its own `README.md` explaining the exact workflow and files included.

---

# ⚙️ Requirements

### Platform

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Service Requirement

* Microsoft Intune with **custom compliance policy** support

---

# 🧭 Usage Model

1. Open the target project folder
2. Review the included `README.md`
3. Adjust any package-specific configuration values
4. Upload the PowerShell script and JSON rule to Intune as needed

---

# 🛡 Operational Notes

* These projects are primarily **reporting/compliance** assets, not remediation packages.
* Exact matching logic, JSON shape, and supported conditions vary by project.
* Always test the returned JSON against the intended Intune compliance rule before production use.

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

