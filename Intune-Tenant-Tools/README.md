<div align="center">

# 🏢 Intune Tenant Tools

**Tenant configuration governance: backup, audits, groups, and RBAC**

Nine Graph-powered workstation tools for configuration lifecycle, assignment visibility, and role governance — backup and restore with manifest-tracked JSON, drift and filter audits, assignment matrix and per-group analysis, RBAC review, plus bulk remediation and driver approval.

[![Intune](https://img.shields.io/badge/Intune-Tenant%20Tools-10B981?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [Operational Notes](#-operational-notes) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Tenant Tools** is the tenant governance category for Microsoft Intune — seven root scripts plus two subfolder tools covering the full configuration lifecycle.

The suite exports and restores device configuration profiles, settings catalog policies, compliance policies, ADMX templates, and platform scripts as versionable JSON; audits assignment filters, builds assignment matrices, answers "what does this group get," surfaces role assignments for access reviews, compares tenant state against a baseline to flag drift, and provides on-demand remediation triggers and bulk driver approvals. Every tool runs **from an admin workstation** via Microsoft Graph — interactive delegated sign-in (WAM-free via `MgGraphCommunity` when available) or app-only (`-TenantId` / `-ClientId` + `-ClientSecret` or `-CertificateThumbprint`) — with no Azure Automation or endpoint deployment dependency.

---

# ✨ Core Features

### 🔹 Backup / Restore with JSON Handling
* `Backup-IntuneConfiguration.ps1` exports DeviceConfigurations, SettingsCatalog (with per-policy `settings` expansion), CompliancePolicies (`scheduledActionsForRule` expansion), AdmxPolicies (`definitionValues` + `presentationValues` expansion), and PlatformScripts (Windows + macOS) — each object as one JSON file including `assignments`, plus `manifest.json`. Uses `ConvertTo-Json -Depth 25` and beta Graph endpoints; secrets are never exported.
* `Restore-IntuneConfiguration.ps1` recreates objects as **new entries** from a backup folder, strips read-only properties (`id`, timestamps, `assignments`, `@odata.*`), supports `-WhatIf` preview via `SupportsShouldProcess`, and optionally restores assignments (`-RestoreAssignments`) when source group IDs exist in the target tenant. Handles `scheduledActionsForRule` fallbacks and ADMX `definition@odata.bind` creation.

### 🔹 Assignment Audits & Group Visibility
* **Assignment Filter Audit** — scans every assignment surface (configuration, settings catalog, compliance, ADMX, PowerShell/shell scripts, remediation scripts, apps) for `deviceAndAppManagementAssignmentFilterId` / `Type` references; reports unused filters and duplicate filters (same platform + whitespace-normalized rule).
* **Assignment Matrix** — flattens every assignment into `Surface / Name / TargetType / GroupName / Intent / FilterName / FilterMode` rows with cached group-name resolution and optional `-IncludeUnassigned`; answers "what targets this population" in one CSV.
* **Group Assignments** — given a single Entra group by name or ID (exact match required), lists everything directly assigned to it across all surfaces with `Included` / `Excluded` / `All Users` / `All Devices` classification and filter mode, plus optional tenant-wide inclusion.

### 🔹 Drift Comparison
* `Compare-PolicyDrift.ps1` compares a baseline backup folder (by ID-matched `manifest.json`) against live tenant state for settings catalog, configuration profiles, and compliance policies using normalized JSON (volatile `lastModifiedDateTime`, `version`, `assignments` etc. removed). Classifies each object as `Added` / `Modified` / `Deleted` and supports CSV export.

### 🔹 RBAC & Bulk Operations
* **RBAC Audit** — enumerates `roleDefinitions` and `roleAssignments` (per-assignment `$expand=roleDefinition`), resolves user/group principals with 429 retry, groups by role (built-in vs. custom), shows scopes and members, and optionally lists empty roles; CSV export flattens members per assignment.
* **Bulk Remediation** — triggers `initiateOnDemandProactiveRemediation` for a chosen `deviceHealthScript` across selected `managedDevices` (beta endpoints) with GridView pickers or fully parameterized `-RemediationId`/`-DeviceId` for headless runs; preserves legacy payload shape including trailing comma.
* **Driver Approval** — approves every driver with `category eq 'other' and approvalStatus eq 'needsreview'` across all `windowsDriverUpdateProfiles` via `microsoft.graph.executeAction` with an ISO 8601 `deploymentDate`; fully paginated inventories with retry-aware Graph calls.

### 🔹 Enterprise-Ready Execution
* Workstation dual-mode auth for every audit/backup script; interactive scopes are requested via `MgGraphCommunity` (WAM-free) with fallback to `Microsoft.Graph.Authentication`.
* Throttling-aware pagination (`Get-MgGraphAllPages`, `Invoke-MgGraphRequestWithRetry` honoring `Retry-After`, max 5 attempts / 60s on 429/503).
* Structured, timestamped logging to `C:\ProgramData\<SolutionName>\Logs\` and `Write-Banner` / `Write-Log` / `Finish-Script`.

---

# 📂 Project Structure

```text
Intune-Tenant-Tools
│
├── Backup-IntuneConfiguration.ps1
├── Restore-IntuneConfiguration.ps1
├── Compare-PolicyDrift.ps1
├── Get-AssignmentFilterAudit.ps1
├── Get-AssignmentMatrix.ps1
├── Get-GroupAssignments.ps1
├── Get-IntuneRoleAssignments.ps1
├── Invoke-BulkRemediation/
│   └── Invoke-BulkRemediation.ps1
├── Approve-IntuneDriverUpdates/
│   └── Approve-IntuneDriverUpdates.ps1
└── README.md
```

> 7 loose `.ps1` files at the category root + 2 subfolders = **9 tools total**. `Approve-IntuneDriverUpdates-AppAuth.ps1` has been removed (now consolidated into `Approve-IntuneDriverUpdates.ps1`).

---

# 📜 Scripts Included

| Script | Purpose | Graph Permissions | Run Context |
| ------ | ------- | ----------------- | ----------- |
| `Backup-IntuneConfiguration.ps1` | Exports Intune configuration (DeviceConfigurations, SettingsCatalog with settings, CompliancePolicies, AdmxPolicies with definitionValues, PlatformScripts) to a timestamped folder as per-object JSON + `manifest.json`. Supports `-Areas` and `-SkipScriptContent`. | `DeviceManagementConfiguration.Read.All` | Workstation — interactive (delegated) or app-only (`-TenantId`/`-ClientId` + `-ClientSecret` or `-CertificateThumbprint`) |
| `Restore-IntuneConfiguration.ps1` | Recreates objects from a backup folder as new entries; strips read-only properties, supports `-NamePrefix`, `-Areas`, and optional `-RestoreAssignments`; every create honors `-WhatIf` via `SupportsShouldProcess`. | `DeviceManagementConfiguration.ReadWrite.All` | Workstation — interactive or app-only; `SupportsShouldProcess` / `-WhatIf` |
| `Compare-PolicyDrift.ps1` | Compares a baseline backup against live tenant state (Settings Catalog, DeviceConfigurations, CompliancePolicies) by normalized JSON; reports Added / Modified / Deleted. Optional CSV export. | `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only |
| `Get-AssignmentFilterAudit.ps1` | Audits all assignment filters and cross-references every assignment surface; reports used vs. unused filters and duplicates (same platform + normalized rule). Optional CSV export. | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All` | Workstation — interactive or app-only |
| `Get-AssignmentMatrix.ps1` | Builds a flattened who-gets-what matrix across 8 surfaces (configurations, settings catalog, compliance, ADMX, PowerShell/shell scripts, remediations, apps) with target type, group name (cached), intent, and filter mode. Optional `-IncludeUnassigned` and CSV export. | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All`, `Group.Read.All` | Workstation — interactive or app-only |
| `Get-GroupAssignments.ps1` | Lists everything Intune assigns to a single Entra group (by name or ID; exact match) across all surfaces; flags exclusions and optionally includes tenant-wide All Users / All Devices. Optional CSV export. | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementScripts.Read.All`, `GroupMember.Read.All` | Workstation — interactive or app-only |
| `Get-IntuneRoleAssignments.ps1` | Lists all Intune role definitions and assignments (built-in + custom), resolves users/groups, shows scopes and assignment dates; optionally includes empty roles. Optional CSV export. | `DeviceManagementRBAC.Read.All`, `User.Read.All`, `Group.Read.All` | Workstation — interactive or app-only |
| `Invoke-BulkRemediation/Invoke-BulkRemediation.ps1` | Triggers a proactive remediation (`deviceHealthScripts`) on demand across selected managed devices via `initiateOnDemandProactiveRemediation`; GridView pickers for interactive runs or `-RemediationId`/`-DeviceId` for headless/app-only runs. | Interactive: `Group.ReadWrite.All`, `Device.ReadWrite.All`, `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementServiceConfig.ReadWrite.All`, `GroupMember.ReadWrite.All`, `Domain.ReadWrite.All`, `Organization.Read.All`, `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementScripts.ReadWrite.All`; App-only: matching application permissions with admin consent | Workstation — interactive MFA or app-only (`-Tenant`/`-ClientId`/`-ClientSecret`); desktop host required for `Out-GridView` pickers |
| `Approve-IntuneDriverUpdates/Approve-IntuneDriverUpdates.ps1` | Approves every pending Windows driver update (`category eq 'other' and approvalStatus eq 'needsreview'`) across all `windowsDriverUpdateProfiles` via `microsoft.graph.executeAction` with ISO 8601 deployment date; fully paginated. | `DeviceManagementConfiguration.ReadWrite.All` (delegated; application permission for app-only) | Workstation — interactive MFA or app-only (`-TenantId`/`-AppId`/`-AppSecret`) |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (admin workstation)

### PowerShell
* PowerShell **5.1 or later**

### Modules
* `Microsoft.Graph.Authentication` — required for all 9 tools; auto-installed when missing (prompt or `-ForceModuleInstall`)
* `MgGraphCommunity` — auto-installed when available to provide WAM-free interactive sign-in on Windows (all tools except BulkRemediation/DriverApproval which use `Microsoft.Graph.Authentication` directly)
* `Microsoft.Graph.Beta.DeviceManagement.Actions` — required for `Approve-IntuneDriverUpdates.ps1` (auto-installed per-user)

```powershell
Install-Module Microsoft.Graph.Authentication -Scope CurrentUser
```

### Permissions
* Least-privilege Graph scopes per script as listed above; consent the union for batch runs.
* Entra role: **Intune Administrator** for backup/audits/drift/matrix/group/RBAC reads; **Intune Service Administrator** (or equivalent) for restore, bulk remediation triggers, and driver approvals.
* Bulk remediation app-only registrations must have the listed application permissions with admin consent; driver approval needs `DeviceManagementConfiguration.ReadWrite.All` with admin consent.

### Logging
* `C:\ProgramData\<SolutionName>\Logs\` — e.g. `C:\ProgramData\backup-intune-configuration\Logs\`, `C:\ProgramData\get-assignment-filter-audit\Logs\`, `C:\ProgramData\Invoke-BulkRemediation\Logs\`, `C:\ProgramData\Approve-IntuneDriverUpdates\Logs\`
* Relative `-OutputPath` / `-BackupPath` values resolve beside the script, not the caller's working directory.

---

# 🛡 Operational Notes

* **Backup JSON depth 25:** `Backup-IntuneConfiguration.ps1` writes each object with `ConvertTo-Json -Depth 25` (manifest uses depth 5) so nested settings catalog and ADMX presentation values survive round-tripping. Restore uses `-Depth 25` (settings catalog: 30) on create payloads. Graph never returns secret values (encrypted OMA-URI, passwords, certificates) — those appear as secret references and must be re-entered manually after restore.
* **Restore supports ShouldProcess / WhatIf:** `Restore-IntuneConfiguration.ps1` is declared with `[CmdletBinding(SupportsShouldProcess = $true)]` — every `deviceConfigurations`, `configurationPolicies`, `deviceCompliancePolicies`, `groupPolicyConfigurations`, and `deviceManagementScripts` create is gated by `$PSCmdlet.ShouldProcess`. Run with `-WhatIf` to preview all creates without writing to the tenant. Objects are always created as new entries; re-running with the same backup creates duplicates. Assignment restore (`-RestoreAssignments`) requires source group IDs to exist in the target tenant and is reported per object.
* **RBAC export sensitivity:** `Get-IntuneRoleAssignments.ps1` resolves and exports Intune role membership (users, groups, scopes) — treat the CSV as sensitive. Per-assignment `$expand=roleDefinition` is fetched individually because the list endpoint does not link assignments to roles; throttled principal lookups retry once after 60s. Use `-ShowEmptyRoles` only for completeness reviews.
* **BulkRemediation device-targeting:** `Invoke-BulkRemediation.ps1` targets `devicemanagement/managedDevices` and posts to `managedDevices('<id>')/initiateOnDemandProactiveRemediation` (beta) with the legacy body `{"ScriptPolicyId":"<id>",}` (trailing comma preserved). Interactive mode opens `Out-GridView` pickers for remediation and devices — on headless hosts always pass `-RemediationId` and `-DeviceId`; when raw IDs are passed the display-name lookup is skipped. All calls use `Invoke-MgGraphRequestWithRetry` (429/503 honoring `Retry-After`, max 5 attempts) and `Get-MgGraphAllPages`.
* **Driver approval is immediate and irreversible:** `Approve-IntuneDriverUpdates.ps1` approves every driver currently in `needsreview` with deployment date `now` (ISO 8601). The profile list is read from the first page only (legacy behavior); driver inventories are fully paginated and filtered to `category eq 'other' and approvalStatus eq 'needsreview'`. Test in a staging tenant and never hardcode client secrets — inject from a secret store at runtime.
* **Beta endpoints:** All tools intentionally remain on `https://graph.microsoft.com/beta` because the full Intune configuration surface (settings catalog bodies, ADMX, assignment filters, driver inventories, role assignments) is not exposed on `v1.0`.
* **Throttling:** Every Graph tool pages with `Get-MgGraphAllPages` and retries on 429/503. Large tenants will pause automatically; do not abort on the first throttling message.
* **Common:** All scripts disconnect (`Disconnect-MgGraph`) and write structured logs. Test in a staging tenant before production.

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
