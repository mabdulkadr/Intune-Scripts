<div align="center">

# 📱 Delivery Optimization Troubleshooting

**Verifies and repairs the local Windows Delivery Optimization stack (service, ports, Teredo, endpoints, bandwidth policies, connectivity, firewall).**

Runs a full set of local health probes for Delivery Optimization: it checks the DoSvc service
    (starting it when stopped), tests required TCP/UDP ports, inspects and repairs the Teredo state,
    lists active Delivery Optimization jobs, probes Microsoft delivery endpoints over HTTP, reads the
    Delivery Optimization bandwidth policy registry key, pings a general connectivity target, and
    enumerates Delivery Optimization firewall rules.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Structure](#-project-structure) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Delivery Optimization Troubleshooting** is a PowerShell script that Runs a full set of local health probes for Delivery Optimization: it checks the DoSvc service (starting it when stopped), tests required TCP/UDP ports, inspects and repairs the Teredo state, lists active Delivery Optimization jobs, probes Microsoft delivery endpoints over HTTP, reads the Delivery Optimization bandwidth policy registry key, pings a general connectivity target, and enumerates Delivery Optimization firewall rules. This is a purely local tool - it never calls Microsoft Graph. It DOES modify the system when a component is unhealthy: Start-Service on DoSvc and "netsh interface teredo set state enterpriseclient".

Runs a full set of local health probes for Delivery Optimization: it checks the DoSvc service (starting it when stopped), tests required TCP/UDP ports, inspects and repairs the Teredo state, lists active Delivery Optimization jobs, probes Microsoft delivery endpoints over HTTP, reads the Delivery Optimization bandwidth policy registry key, pings a general connectivity target, and enumerates Delivery Optimization firewall rules. This is a purely local tool - it never calls Microsoft Graph. It DOES modify the system when a component is unhealthy: Start-Service on DoSvc and "netsh interface teredo set state enterpriseclient". It runs **locally with no Graph calls** and writes structured logs for every operation.

---

# ✨ Features

* Checks DoSvc service status and starts it when stopped
* Probes required TCP 7680 / UDP 3544 / TCP 443 ports against www.microsoft.com
* Inspects Teredo state and auto-repairs via `netsh interface teredo set state enterpriseclient` when not qualified
* Lists live Delivery Optimization jobs and probes four Microsoft delivery endpoints (10s timeout)
* Dumps bandwidth-policy registry key, pings 8.8.8.8 for connectivity, and inventories DO firewall rules

---

# 📂 Project Structure

```text
Set-DeliveryOptimization
│
├── Set-DeliveryOptimization.ps1
└── README.md
```

---

# 🚀 Usage

### Basic Usage
```powershell
.\Set-DeliveryOptimization.ps1
```
Runs every check in sequence and reports each result in the console and log file.

### Example 2
```powershell
.\Set-DeliveryOptimization.ps1
```
Run from an elevated prompt after Delivery Optimization download stalls to repair DoSvc/Teredo automatically.

---

# ⚙️ Parameters

| Parameter | Type | Required | Default | Description |
|-----------|------|----------|---------|-------------|
| None | — | — | — | The script is fully self-contained |

### Exit Codes
| Code | Status |
| ---- | ------ |
| 0    | Success |
| 1    | Failure (validation or Graph error) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Modules
* No Graph modules required — local execution only.

### Permissions
* Run from an **elevated** console — local administrator rights required. No Graph permissions required; inspects services, registry, and network state locally.

### Logging
* `C:\ProgramData\DeliveryOptimization\Logs`

---

# 🛡️ Operational Notes

* This tool modifies the system by design: it starts DoSvc and switches Teredo to `enterpriseclient` mode when they are unhealthy.
* Purely local execution — no Microsoft Graph calls, no tenant data accessed.
* Port tests target `www.microsoft.com`; endpoint tests use a 10-second timeout per URL.
* A missing bandwidth-policy registry key is reported as informational (defaults in use), not as an error.
* Rerun after repairs to confirm Teredo reaches qualified state.

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
