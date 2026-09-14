<div align="center">

# 🩺 Intune Diagnostics

**Health checks and failure analysis**

[![Intune](https://img.shields.io/badge/Intune-Diagnostics-10B981?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-1.2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [Operational Notes](#-operational-notes) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Diagnostics** is a focused collection of workstation-run health and failure-analysis scripts for Microsoft Intune.

The category surfaces devices that are drifting toward unmanaged state, collects remote diagnostic packages at scale, and explains enrollment and Autopilot failures without portal click-through. Every script runs **LocalOnly from an admin workstation** (or an Azure Automation runbook where noted) via Microsoft Graph — interactive delegated sign-in (WAM-free via `MgGraphCommunity`) or app-only patterns — and emits structured console output with optional CSV export.

---

# ✨ Core Features

### 🔹 Check-in Health
* Buckets every managed device into **Healthy / Drifting / Stale / Never synced** based on `lastSyncDateTime`
* Per-platform distribution and actionable detail for the drifting tail

### 🔹 Diagnostics Collection at Scale
* Triggers the Intune **Collect diagnostics** remote action on Windows devices by name or Entra ID group, polls until `completed`, and downloads the ZIPs
* `DownloadExisting` mode fetches the latest completed package without triggering a new collection

### 🔹 Enrollment & Autopilot Failure Analysis
* Reads `deviceManagement/troubleshootingEvents` (enrollment) and `deviceManagement/autopilotEvents` and translates `failureCategory` into plain-language explanations with typical fixes
* Resolves `userId → userPrincipalName` and groups failures by category

---

# 📂 Project Structure

```text
Intune-Diagnostics
│
├── Collect-DeviceDiagnostics.ps1
├── Get-DeviceCheckinHealth.ps1
├── Get-EnrollmentFailureReport.ps1
└── README.md
```

---

# 📜 Scripts Included

| Script | Purpose | Permissions | Run Context |
| ------ | ------- | ----------- | ----------- |
| `Collect-DeviceDiagnostics.ps1` | Triggers remote **Collect diagnostics** on Windows devices (by `-DeviceNames` or `-GroupName`), waits for completion, and downloads ZIP packages to `-OutputPath` | `DeviceManagementManagedDevices.ReadWrite.All`, `GroupMember.Read.All` | Workstation **or** Azure Automation (Managed Identity). Interactive via `MgGraphCommunity` locally; `Connect-MgGraph -Identity` in Automation. **LocalOnly / Runbook** — Windows-only action; non-Windows devices are skipped |
| `Get-DeviceCheckinHealth.ps1` | Analyzes sync cadence and highlights degrading check-in behavior; buckets devices as Healthy (≤ `-HealthyDays`), Drifting, Stale (> `-StaleDays`), and Never synced | `DeviceManagementManagedDevices.Read.All` | Workstation **or** Azure Automation. **LocalOnly / Runbook** |
| `Get-EnrollmentFailureReport.ps1` | Reports enrollment troubleshooting events and (optionally) Autopilot deployment events with plain-language failure explanations | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementServiceConfig.Read.All`, `User.Read.All` | Workstation **or** Azure Automation. **LocalOnly / Runbook** |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (admin workstation; Automation runbooks also supported where noted)

### PowerShell
* PowerShell **5.1 or later**

### Modules
* `Microsoft.Graph.Authentication` (auto-installed if missing; `MgGraphCommunity` for WAM-free interactive sign-in on workstations)

### Permissions
* Per-script Graph permissions as listed above (delegated scopes for interactive, application scopes for app-only / Managed Identity)
* Intune Administrator or equivalent

### Run Context
* Workstation **LocalOnly** or Azure Automation runbook (Managed Identity) — scripts detect `$PSPrivateMetadata.JobId.Guid` and switch connection accordingly

---

# 🛡 Operational Notes

* **Collect-DeviceDiagnostics — targeting:** Specify exactly one target: `-DeviceNames` **or** `-GroupName`. Group members are resolved via Entra group `members` → `deviceId` → Intune `azureADDeviceId`. Non-Windows devices are skipped with a warning — Collect diagnostics is a Windows 10/11-only action.
* **Collect-DeviceDiagnostics — modes:** Without `-DownloadExisting` the script `POST`s `createDeviceLogCollectionRequest` per device (`templateType = predefined` nested object) and polls every 30s until `completed`/`failed` or `-TimeoutMinutes` (default 15, max 120). With `-DownloadExisting "true"` it lists `logCollectionRequests`, picks the newest `completed` (`receivedDateTimeUTC` / `requestedDateTimeUTC`), and calls `createDownloadUrl` — the returned URL is a pre-authenticated Azure Storage link fetched via `Invoke-WebRequest`, not `Invoke-MgGraphRequest`.
* **Collect-DeviceDiagnostics — offline devices:** Devices that do not complete within the timeout remain in `pendingRequests` and are reported as `Failures/timeouts`. Re-run later with `-DownloadExisting` to fetch the package once the device comes online.
* **Get-DeviceCheckinHealth — thresholds:** `-HealthyDays` (1–90, default 7) must be smaller than `-StaleDays` (2–365, default 30). Devices with no `lastSyncDateTime` are bucketed as **Never synced**. The **Drifting** bucket (7–30 days by default) is the actionable intervention window before stale. Export includes `DaysSinceSync`, `HealthBucket`, `OperatingSystem`, and `ComplianceState`.
* **Get-EnrollmentFailureReport — retention:** Troubleshooting events are retained by Intune for a limited period — older failures may no longer be available. The script filters with `eventDateTime ge <cutoff>` where cutoff is `Now - DaysBack` (1–180, default 30). Enrollment events are selected by `@odata.type == enrollmentTroubleshootingEvent` or presence of `failureCategory`.
* **Get-EnrollmentFailureReport — Autopilot:** Add `-IncludeAutopilotEvents "true"` to also list `autopilotEvents` within the same window, showing `deploymentState` / `enrollmentState` per serial number. Outputs are grouped by `failureCategory` with explanations (e.g., `enrollmentRestrictionsEnforced`, `authorization`, `authentication`).
* **Common:** Beta Graph endpoints are used across the category; paging handles `429` with a 60s backoff. Logs are written to Intune or General locations via the canonical `Initialize-Log` / `Write-Banner` / `Write-Log` block. `-OutputPath` defaults to the script directory (Law 12). Test in a staging group before production.

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

---

<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>
