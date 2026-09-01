<div align="center">

# 📊 Find-IntunePolicyConflict

**Troubleshoots Intune policy conflicts and feature side effects on a device with escalating modes.**

Three escalating modes verify policy health: Analyze finds Conflict/Error settings and overlapping CSP paths; Investigate X-rays every setting for a Windows feature area via dependency maps; Isolate guides a binary search with temporary assignment removals and restores all assignments at the end.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Find-IntunePolicyConflict** is a PowerShell reporting script that three escalating modes verify policy health: Analyze finds Conflict/Error settings and overlapping CSP paths; Investigate X-rays every setting for a Windows feature area via dependency maps; Isolate guides a binary search with temporary assignment removals and restores all assignments at the end.

It is designed for helpdesk troubleshooting — Analyze for actual conflicts, Investigate for hardening side effects (e.g., Hello broken after baseline), and Isolate for brute-force binary search when nothing else surfaces the culprit. Analyze and Investigate are read-only; Isolate makes temporary changes and always restores.

---

# ✨ Features

* Analyze: finds Conflict/Error states and overlapping CSP settings
* Investigate: X-rays every setting for a feature via Windows dependency maps (Hello, BitLocker, Defender, etc.)
* Isolate: guided binary search removing half the policies per round — O(log n) with auto-restore
* Resolves Entra group IDs and device/user transitive membership for accurate targeting
* Exports CSV beside the script for overlapping settings and feature analysis

---

# 📂 Project Structure

```text
Find-IntunePolicyConflict
│
├── Find-IntunePolicyConflict.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Find-IntunePolicyConflict.ps1
```

### Example 1
```powershell
.\Find-IntunePolicyConflict.ps1 -DeviceName "L-PF4Z0HM0"
```
Runs Analyze mode to find conflicts and errors.

### Example 2
```powershell
.\Find-IntunePolicyConflict.ps1 -DeviceName "L-PF4Z0HM0" -Mode Investigate -Feature Hello
```
X-rays every setting that could affect Windows Hello.

### Example 3
```powershell
.\Find-IntunePolicyConflict.ps1 -DeviceName "L-PF4Z0HM0" -Mode Isolate
```
Runs guided binary search to isolate the culprit policy.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| `DeviceName` | String | Yes | - | Intune device name to troubleshoot. |
| `Mode` | String | No | Analyze | Analyze, Investigate, or Isolate. |
| `Feature` | String | No | - | Feature area for Investigate (Hello, BitLocker, Firewall, etc.). |
| `ExportPath` | String | No | Beside script | Optional CSV export path. |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0 | Success |
| 1 | Failure |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later**

### Permissions
* `DeviceManagementConfiguration.Read.All, DeviceManagementManagedDevices.Read.All, Device.Read.All, Directory.Read.All, Group.Read.All, GroupMember.Read.All`

### Logging
* `C:\ProgramData\Find-IntunePolicyConflict\Logs\`

---

# 🛡 Operational Notes
* Analyze and Investigate are read-only; Isolate temporarily modifies assignments.
* Isolate requires confirmation (type YES) and restores all assignments in finally.
* Always sync the device and test the broken feature between Isolate rounds.

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