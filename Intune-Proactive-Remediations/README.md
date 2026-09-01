<div align="center">

# 🛡️ Intune-Proactive-Remediations

**The repository's core library of paired Intune proactive remediation packages.**

Standalone detection/remediation projects for cleanup, repair, hardening, notifications, and status reporting — each with its own scripts, logging, and deployment documentation.

[![Intune](https://img.shields.io/badge/Intune-Proactive%20Remediation-10B981?style=for-the-badge)](#%EF%B8%8F-requirements)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Packages](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Intune-Proactive-Remediations** contains the repository's **Microsoft Intune proactive remediation** content.

The packages here are organized as standalone remediation projects, each with its own detection script, remediation script, logging pattern, and project-specific `README.md`. The structure and writing standard in this area are also used as the baseline for the rest of the repository.

---

# ✨ Core Features

### 🔹 Project-Based Remediation Packages
Each remediation scenario lives in its own folder so detection logic, remediation logic, and documentation stay together.

### 🔹 Unified Script Structure
Packages in this area follow a common structure for:

* `Configuration`
* `Functions`
* `Detection Logic` or `Remediation Logic`
* Logging to the `IntuneLogs\<SolutionName>` path on the system drive

### 🔹 Standardized Documentation
Every remediation package includes a `README.md` that explains what the package checks, what it changes, and how it should be deployed.

### 🔹 Local Logging
Uses the standardized Intune-style logging pattern under `<SystemDrive>\IntuneLogs\<PackageName>`, describing the local logging convention used across the remediation package folders.

---

# 📂 Project Structure

```text
Intune-Proactive-Remediations
│
├── Clear-DnsClientCacheImmediate\
├── Disable-FastStartup\
├── Repair-WindowsUpdateComponents\
├── SecureBoot-CA2023-Update\          # NEW 2026 — CA 2023 certificate migration
├── Enable-SecureBoot-Lenovo\           # NEW 2026 — WMI BIOS enablement
├── Disable-LLMNR-NetBIOS\              # NEW 2026 — CIS L1 hardening
├── Clear-TeamsCache\                   # NEW 2026 — Teams classic + new
├── Get-BatteryHealth\                  # NEW 2026 — battery degradation
├── Test-WindowsLapsDrift\              # NEW 2026 — legacy vs Windows LAPS
├── ...one folder per remediation scenario (68+ total)...
│   ├── detect-<SolutionName>.ps1
│   ├── remediate-<SolutionName>.ps1
│   └── README.md
│
└── README.md
```

---

# 📜 Scripts Included

## 📁 Main Collections

* 62+ remediation package folders grouped by scenario (cleanup, repair, hardening, notifications, status)
* Each package is self-contained: `detect-*.ps1` + `remediate-*.ps1` + `README.md`

## 📘 Reference Standard

* Canonical header + logging (`scripts/Write-Log.ps1`) + exit codes `0/1/2`
* See Master `README.md` and `references/_header-canonical.md` for the writing standard

---

# ⚙️ Requirements

### Platform

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Service Requirement

* Microsoft Intune with **Proactive Remediations**

---

# 🧭 Usage Model

1. Open the remediation collection you need
2. Review the package-level `README.md`
3. Validate detection and remediation behavior
4. Deploy the package through Intune Scripts and Remediations

---

# 🛡 Operational Notes

* This folder contains many independent remediation packages with different scopes and prerequisites.
* Some packages are cleanup tools, some are repair workflows, and some are notification or hardening packages.
* Use the package-level `README.md` as the authoritative deployment guide for each remediation.

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
