<div align="center">

# 📱 Intune Device Operations

**Device lifecycle actions and hygiene**

Centralized toolkit for bulk device operations, inventory hygiene, and remote lifecycle actions across your Intune tenant — from CSV-driven membership to wipe, restart, and sync.

[![Intune](https://img.shields.io/badge/Intune-Device%20Operations-0078D4?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Core Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [Operational Notes](#-operational-notes) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Device Operations** is the device-lifecycle category of the Intune Scripts repository. It groups 15 production-ready PowerShell tools that operate on `deviceManagement/managedDevices` and related Graph surfaces to keep your fleet clean, compliant, and responsive.

Scripts cover four operator workflows: **bulk targeting** (CSV → Entra ID groups, app-based groups, renames), **hygiene / cleanup** (stale detection, duplicate purge, orphaned Autopilot removal), **remote actions** (wipe, restart, sync), and **reporting / remediation** (Scope Tag inventory, outdated iOS, Windows 11 readiness, primary-user repair, Delivery Optimization diagnostics).

Every Graph script supports dual authentication — **interactive delegated** (MgGraphCommunity, WAM-free) and **app-only** (client secret or certificate) — with beta endpoints, paginated collection helpers, and retry-aware 429 handling. Local-only diagnostics run elevated without any Graph dependency.

---

# ✨ Core Features

### 🔹 Bulk Group Add
* `Add-DevicesToGroupsFromCsv.ps1` — CSV-driven Entra ID group membership with DeviceId > SerialNumber > DeviceName matching, delimiter auto-detection, idempotent skip-if-already-member, optional auto-create, and `-DryRun` preview.

### 🔹 Autopilot Cleanup
* `Remove-StaleAutopilotDevices.ps1` — finds Autopilot registrations whose serial numbers no longer exist in Intune and removes orphans; `-PreviewOnly` gate before any delete, sanitized `0001-01-01` dates, and throttled batch deletes.

### 🔹 Duplicate Purge
* `Remove-DuplicateDeviceRecords.ps1` — groups Intune records by serial number, keeps the most-recent sync (`lastSyncDateTime` → `enrolledDateTime` fallback), and deletes older duplicates; placeholder serials excluded, report/export and `-WhatIf` supported.

### 🔹 Stale Detection
* `Get-StaleDevices.ps1` — flags devices not checked in for *N* days (all platforms, optional platform filter, `IncludeNeverCheckedIn`) with CSV/HTML-friendly output.
* `Get-DevicesByScopeTag.ps1` — Scope Tag-filtered inventory with HTML report, compliance/platform filters, and cached scope-tag resolution.
* `Get-OutdatedIosDevices.ps1` — iOS devices below the two latest major releases (default 26/18), major-version parsing with unrecognized-version warnings.
* `Get-Windows11Readiness.ps1` — Endpoint Analytics work-from-anywhere hardware signals (TPM, Secure Boot, RAM, storage, CPU family/speed/cores, 64-bit) with tenant summary and per-device failed-check breakdown.

### 🔹 Wipe / Restart / Sync
* `Invoke-DeviceWipe.ps1` — selective (retire) or full (factory reset) wipe by device names, IDs, or Entra group; `keepEnrollmentData`, macOS PIN handling, `DryRun` preview, and explicit `CONFIRM` gate.
* `Restart-IntuneDevices.ps1` — `rebootNow` remote action with the same targeting modes, throttled retries, and confirmation.
* `Sync-IntuneDevices.ps1` — `syncDevice` action with 1-hour skip logic (`-ForceSync` to override) and group/name/ID targeting.
* `Sync-AllIntuneDevices/Sync-AllIntuneDevices.ps1` — tenant-wide `syncDevice` burst for every managed device (interactive and app-only paths).

### 🔹 Primary User Repair
* `Repair-PrimaryUserAssignment.ps1` — compares `usersLoggedOn` (most-recent logon) to Intune primary user on Windows devices; `-Apply` corrects via `users/$ref` after resolving enabled UPNs.

### 🔹 Delivery Optimization
* `Set-DeliveryOptimization/Set-DeliveryOptimization.ps1` — **local-only** health pass: DoSvc service, TCP 7680/443 + UDP 3544, Teredo `enterpriseclient` repair, live DO jobs, four Microsoft endpoint probes, bandwidth-policy registry dump, connectivity ping, and firewall rule inventory; mutating only on DoSvc/Teredo.

### 🔹 Additional Bulk Ops
* `Rename-DevicesFromCsv.ps1` — `setDeviceName` bulk rename from `DeviceName,NewName` CSV with 15-char/Hyphen validation and `-DryRun`/`-WhatIf`.
* `New-AppBasedGroups.ps1` — Entra ID groups from installed apps (detected apps + report-based install status), wildcard app names, type/platform filters, and version gating.

---

# 📂 Project Structure

```text
Intune-Device-Operations
│
├── Add-DevicesToGroupsFromCsv.ps1
├── Get-DevicesByScopeTag.ps1
├── Get-OutdatedIosDevices.ps1
├── Get-StaleDevices.ps1
├── Get-Windows11Readiness.ps1
├── Invoke-DeviceWipe.ps1
├── New-AppBasedGroups.ps1
├── Remove-DuplicateDeviceRecords.ps1
├── Remove-StaleAutopilotDevices.ps1
├── Rename-DevicesFromCsv.ps1
├── Repair-PrimaryUserAssignment.ps1
├── Restart-IntuneDevices.ps1
├── Sync-IntuneDevices.ps1
│
├── Set-DeliveryOptimization/
│   └── Set-DeliveryOptimization.ps1
│
├── Sync-AllIntuneDevices/
│   └── Sync-AllIntuneDevices.ps1
│
└── README.md
```

---

# 📜 Scripts Included

| Script | Purpose | Graph Permissions | Run Context | DANGER |
|--------|---------|-----------------|-------------|--------|
| `Add-DevicesToGroupsFromCsv.ps1` | Bulk-add Intune devices to Entra ID groups from CSV (DeviceId/Serial/DeviceName priority, idempotent, optional group creation) | `Group.ReadWrite.All`, `DeviceManagementManagedDevices.Read.All`, `Directory.Read.All` | Graph — delegated or app-only | — |
| `Get-DevicesByScopeTag.ps1` | Scope Tag-filtered device inventory with CSV + interactive HTML report | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementRBAC.Read.All` | Graph — delegated or app-only | — |
| `Get-OutdatedIosDevices.ps1` | Reports iOS devices below the two latest major releases (parse-safe, timestamped CSV) | `DeviceManagementManagedDevices.Read.All` | Graph — delegated or app-only | — |
| `Get-StaleDevices.ps1` | Finds devices stale for N days (platform filter, include never-checked-in) | `DeviceManagementManagedDevices.Read.All` | Graph — delegated or app-only | — |
| `Get-Windows11Readiness.ps1` | Windows 11 upgrade readiness via Endpoint Analytics hardware signals | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.Read.All` | Graph — delegated or app-only | — |
| `Invoke-DeviceWipe.ps1` | Remote wipe (Selective retire / Full factory reset) by names, IDs, or Entra group | `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementManagedDevices.Read.All`, `GroupMember.Read.All` | Graph — delegated or app-only | 🔴 **DANGER — Irreversible** |
| `New-AppBasedGroups.ps1` | Creates/updates Entra ID groups containing devices with a given installed app | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementApps.Read.All`, `Group.ReadWrite.All`, `Directory.Read.All` | Graph — delegated or app-only | — |
| `Remove-DuplicateDeviceRecords.ps1` | Deletes older duplicate Intune records sharing a serial number (keeps newest sync) | `DeviceManagementManagedDevices.ReadWrite.All` | Graph — delegated or app-only | 🟠 **DANGER — Deletes records** |
| `Remove-StaleAutopilotDevices.ps1` | Removes orphaned Autopilot registrations whose serials no longer exist in Intune | `DeviceManagementServiceConfig.ReadWrite.All`, `DeviceManagementManagedDevices.Read.All` | Graph — delegated or app-only | 🟠 **DANGER — Deletes Autopilot** |
| `Rename-DevicesFromCsv.ps1` | Bulk `setDeviceName` renames from DeviceName→NewName CSV with validation | `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementManagedDevices.Read.All` | Graph — delegated or app-only | — |
| `Repair-PrimaryUserAssignment.ps1` | Realigns Windows primary user to most-recent logged-on user | `DeviceManagementManagedDevices.ReadWrite.All`, `User.Read.All` | Graph — delegated or app-only | — |
| `Restart-IntuneDevices.ps1` | Remote `rebootNow` by names, IDs, or Entra group | `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementManagedDevices.Read.All`, `GroupMember.Read.All` | Graph — delegated or app-only | — |
| `Sync-IntuneDevices.ps1` | Targeted `syncDevice` with 1-hour skip logic and ForceSync override | `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementManagedDevices.Read.All`, `GroupMember.Read.All` | Graph — delegated or app-only | — |
| `Set-DeliveryOptimization/Set-DeliveryOptimization.ps1` | Local Delivery Optimization health & repair (DoSvc, ports, Teredo, jobs, endpoints, policies, firewall) | *None — local only* | **Local elevated (no Graph)** — Administrator required | — |
| `Sync-AllIntuneDevices/Sync-AllIntuneDevices.ps1` | Tenant-wide `syncDevice` burst to every managed device | `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementConfiguration.ReadWrite.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `CloudPC.ReadWrite.All`, `Domain.Read.All`, `Directory.Read.All` | Graph — delegated or app-only | — |

> DANGER flags mark scripts that permanently delete or wipe data/registrations. All three expose preview modes — use them first.

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1`)

### Modules
```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
# Auto-installed when missing: MgGraphCommunity (WAM-free interactive sign-in)
```
* `Set-DeliveryOptimization/Set-DeliveryOptimization.ps1` requires no Graph modules — local execution only.
* `Sync-AllIntuneDevices/Sync-AllIntuneDevices.ps1` uses `Microsoft.Graph.Authentication` directly.

### Permissions
* See **Graph Permissions** column in the table above. Grant exactly the listed delegated or application permissions and consent as admin before running.
* Delivery Optimization: run from an **elevated** console — `Start-Service DoSvc` and `netsh interface teredo set state enterpriseclient` require local Administrator.

### Logging
* Graph scripts: `C:\ProgramData\<SolutionName>\Logs\` (timestamped) or `C:\IntuneLogs\` when applicable.
* Delivery Optimization: `C:\ProgramData\DeliveryOptimization\Logs\`
* Sync All: `C:\ProgramData\Sync-AllIntuneDevices\Logs\`

---

# 🛡 Operational Notes

> ### 🔴 DANGER — `Invoke-DeviceWipe.ps1` is irreversible and has no undo
> A **Full** wipe factory-resets the device and permanently erases all user data, apps, and settings. A **Selective** wipe (retire) removes company data, managed apps, and enrollment state. In both cases the device may become unrecoverable. **Before any wipe:** confirm BitLocker recovery keys are escrowed in Entra ID, verify every target with `-DryRun "true"` (and `-WhatIf` where supported), coordinate with affected users, and require an explicit `CONFIRM` prompt (or intentional `-Force "true"` in automation). Never run wide-scope wipes without a second reviewer and a staged pilot.

* **Autopilot cleanup — preview is mandatory.** Always run `Remove-StaleAutopilotDevices.ps1 -PreviewOnly "true"` first and export the orphan list (`-ExportPath`). Removal deletes the Autopilot registration itself; re-registration requires re-importing the hardware hash. Confirm expected serials before using `-RemoveOrphaned "true" -Force "true"`.

* **Duplicate purge — keeper selection is deterministic.** `Remove-DuplicateDeviceRecords.ps1` keeps the record with the most recent `lastSyncDateTime` (falling back to `enrolledDateTime`) per trimmed serial number and marks all older records stale. Placeholder serials (`"", "Defaultstring", "ToBeFilledByOEM", "SystemSerialNumber", "0", "none", "unknown"`) are excluded. Default is report-only; deletion requires `-Remove "true"` (supports `-WhatIf`). Deleting an Intune record does not wipe the device — it only removes the stale management object; Entra device objects and Autopilot registrations are never touched.

* **CSV bulk operations are idempotent.** `Add-DevicesToGroupsFromCsv.ps1` caches group membership once per group, skips devices already in the target group, and validates `DeviceId > SerialNumber > DeviceName` priority per row. `Rename-DevicesFromCsv.ps1` validates Windows computer-name rules (≤15 chars, letters/digits/hyphens, not all digits, no leading/trailing hyphen) before any Graph call and rejects ambiguous name matches. Both support `-DryRun` and `-WhatIf` for safe previews; re-running the same CSV without changes is a no-op.

* **Remote actions are rate-limited.** Wipe/restart/sync scripts honor Graph throttling (HTTP 429) with 60-second back-off and per-device delays (`-WipeDelaySeconds`, `-RestartDelaySeconds`, `-SyncDelaySeconds`). Sync scripts skip devices synced within the last hour unless `-ForceSync "true"`.

* **Endpoint and inventory reports are read-only.** `Get-*` and readiness scripts never modify state; they export timestamped CSV/HTML under the script directory by default. Large tenants should schedule these off-hours and use `-ShowProgressBar` where available.

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

