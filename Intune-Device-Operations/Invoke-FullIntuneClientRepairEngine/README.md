<div align="center">

# 🛠️ Invoke Full Intune Client Repair Engine

**End-to-end Intune client repair for Windows devices (IME + MDM services, deep pipeline reset).**

Performs a best-effort end-to-end repair of the Intune client stack: restarts core Intune/MDM services, triggers policy + compliance sync, kicks the IME for Win32 apps and remediations, and (in deep mode) repairs the download pipeline and clears the IME cache.

[![Mode](https://img.shields.io/badge/Mode-CLI-334155?style=for-the-badge)](#-usage)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-features) • [Usage](#-usage) • [Parameters](#%EF%B8%8F-parameters) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

The Intune Client Repair Engine is a single-file PowerShell tool that performs a **best-effort, end-to-end repair of the Intune client stack** on Windows devices. It runs locally with **no Graph calls**, detects elevation at runtime, and self-relaunches as Administrator when needed.

The engine runs six logical stages:

1. **Restart Intune/MDM core services** — `IntuneManagementExtension`, `dmwappushservice`, and the enrollment service (varies by build).
2. **Restart notification services** — `WpnService`.
3. **MDM policy/compliance sync** — starts every enabled `EnterpriseMgmt` scheduled task and (optionally) runs `deviceenroller.exe /o <guid> /c /b`.
4. **IME app/script/remediation kick** — restarts the IME service and (optionally) the process so Win32 apps, PowerShell scripts, and proactive remediations retry.
5. **(Deep mode) Repair download/update pipeline** — restarts `BITS`, `DoSvc`, `UsoSvc`, `wuauserv`.
6. **(Deep mode) IME cache cleanup + final kick** — clears the `Content` folder (and optionally `Logs`) under `Program Files (x86)\Microsoft Intune Management Extension`, then flushes the task channel and re-kicks IME.

It is **best-effort**: behavior varies by Windows build and enrollment state. It does **NOT** unenroll or re-enroll the device.

---

# ✨ Features

* Restarts Intune/MDM core services (IME, MDM push, notification) and the enrollment service
* Triggers MDM policy + compliance sync via `EnterpriseMgmt` scheduled tasks and `deviceenroller.exe`
* Kicks IME for Win32 apps, PowerShell scripts, and Proactive Remediations (service + optional process restart)
* Deep mode repairs the download pipeline (`BITS`, `DoSvc`, `UsoSvc`, `wuauserv`)
* Deep mode clears the IME `Content` cache and re-kicks IME cleanly
* Auto-elevates via `Start-Process -Verb RunAs -Wait` when not run as Administrator
* Canonical `[CmdletBinding()]`, embedded `Write-Log / Initialize-Log / Finish-Script`, top-level `try/catch/finally`

---

# 📂 Project Structure

```text
Invoke-FullIntuneClientRepairEngine
│
├── Invoke-FullIntuneClientRepairEngine.ps1
└── README.md
```

---

# 📜 Scripts

## `Invoke-FullIntuneClientRepairEngine.ps1`

Runs the standard repair pass: restarts services, syncs policy, kicks IME. Add `-DeepRepair` for the full pipeline reset and IME cache clear.

| Stage | Description |
|-------|-------------|
| Core services | Restarts `IntuneManagementExtension`, `dmwappushservice`, the enrollment service, and `WpnService` |
| Policy sync | Starts all enabled `EnterpriseMgmt\<GUID>\` scheduled tasks (excluding Login/Logout) and (optionally) runs `deviceenroller.exe` |
| IME kick | Restarts IME service; optionally restarts the `IntuneManagementExtension` process |
| Deep: pipeline | Restarts `BITS`, `DoSvc`, `UsoSvc`, `wuauserv` |
| Deep: cache | Stops IME, removes `Content` (and optionally `Logs`), starts IME |
| Deep: flush | Re-runs `EnterpriseMgmt` tasks and performs a final IME kick |

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Repair pass completed |
| 1    | Script error (see log) |

### Example

```powershell
.\Invoke-FullIntuneClientRepairEngine.ps1
```

Runs the standard repair pass.

```powershell
.\Invoke-FullIntuneClientRepairEngine.ps1 -DeepRepair
```

Runs the full deep-clean pass including BITS repair and IME cache reset.

```powershell
.\Invoke-FullIntuneClientRepairEngine.ps1 -DeepRepair -ClearImeLogs
```

Deep pass that also clears the IME Logs folder (usually retained for diagnostics).

---

# 🚀 Usage

```powershell
# Standard repair (default)
.\Invoke-FullIntuneClientRepairEngine.ps1

# Deep repair (BITS + IME cache + final kick)
.\Invoke-FullIntuneClientRepairEngine.ps1 -DeepRepair

# Deep repair that also clears IME Logs
.\Invoke-FullIntuneClientRepairEngine.ps1 -DeepRepair -ClearImeLogs
```

---

# ⚙️ Parameters

| Parameter | Type | Default | Description |
|-----------|------|---------|-------------|
| `-DeepRepair` | Switch | Off | Enables the full deep pass: download-pipeline repair, IME cache clear, task channel flush, final IME kick |
| `-EnablePolicySync` | Switch | On | Runs MDM policy/compliance sync (EnterpriseMgmt tasks) |
| `-EnableDeviceEnroller` | Switch | On | Runs `deviceenroller.exe /o <guid> /c /b` after the policy sync |
| `-EnableImeKick` | Switch | On | Restarts the IntuneManagementExtension service (and optionally the process) |
| `-RestartImeProcess` | Switch | On | Stops the IME process so the service relaunches it cleanly |
| `-EnableDeliveryRepair` | Switch | On | (Deep only) Restarts BITS, DoSvc, UsoSvc, wuauserv |
| `-EnableImeCacheCleanup` | Switch | On | (Deep only) Removes the IME `Content` folder |
| `-ClearImeLogs` | Switch | Off | (Deep only) Also removes the IME `Logs` folder (usually retained) |

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | Repair pass completed |
| 1    | Script error (see log) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (Server 2016+ with Desktop Experience also supported)

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Modules
* No Graph modules required — local execution only.

### Permissions
* Local **Administrator** rights (auto-elevation via `Start-Process -Verb RunAs` when missing).
* No Graph permissions required; inspects services, scheduled tasks, and the local filesystem only.

### Logging
* `C:\IntuneLogs\Invoke-FullIntuneClientRepairEngine\Invoke-FullIntuneClientRepairEngine-run.txt`

---

# 🛡️ Operational Notes

* Run from an elevated console — the script self-elevates and waits for the elevated instance to finish before returning.
* Deep mode removes the IME `Content` folder; Win32 content will re-download on the next sync. Pass `-ClearImeLogs` only when logs are no longer needed for diagnostics.
* All service and task operations are best-effort. Failures at a single stage are logged as `WARNING` and the engine continues with the remaining stages.
* Does **NOT** unenroll or re-enroll the device; does not delete the IME enrollment GUID.
* Test on a pilot device before running fleet-wide.

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
