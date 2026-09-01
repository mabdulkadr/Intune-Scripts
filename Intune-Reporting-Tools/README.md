<div align="center">

# 📊 Intune Reporting Tools

**Tenant-wide compliance and health reports**

A curated collection of 15 Graph-powered reporting tools that audit compliance, encryption escrow, Apple infrastructure, certificate delivery, connector health, policy hygiene, endpoint analytics, audit logs, and Windows Update — plus a daily tenant HTML executive report.

[![Intune](https://img.shields.io/badge/Intune-Reporting-10B981?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.0.0-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Features](#-core-features) • [Structure](#-project-structure) • [Scripts](#-📜-scripts) • [Requirements](#%EF%B8%8F-requirements) • [Operational Notes](#-operational-notes) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Reporting Tools** is the reporting category of the Intune Scripts library. It inventories and scores the health of an entire Intune tenant from a workstation — no agent deployment required.

The category covers:

* **Compliance** — device compliance summary and per-setting failure reasons (`Get-DeviceComplianceReport`, `Get-NonCompliantDevices`, `Get-CompliancePolicyCoverage`)
* **Encryption escrow** — BitLocker keys in Entra ID and FileVault keys in Intune with compliance percentages (`Test-BitLockerKeys`, `Test-FileVaultKeys`)
* **Apple infrastructure** — DEP token / APNs certificate validity, sync state, and full connector health for DEP/APNs/VPP, Google Play, NDES, certificate connectors and MTD (`Test-AppleTokenValidity`, `Test-ConnectorHealth`)
* **Certificates** — SCEP/PKCS/trusted-root profile validity settings, deployment errors, and decoded root-certificate expiry (`Test-CertificateProfileExpiry`)
* **Policy hygiene** — unassigned policies (Device Configuration, Settings Catalog, Administrative Templates) and recent policy changes via audit events (`Test-UnassignedPolicies`, `Test-PolicyChanges`)
* **Endpoint analytics** — startup performance, app reliability, battery health, and Work From Anywhere scores (`Get-EndpointAnalyticsReport`)
* **Audit logs** — filterable export of Intune audit events to CSV/HTML with 30-day retention awareness (`Export-IntuneAuditLogs`)
* **Windows Update** — update rings with per-device status, feature/quality/driver update profiles, and end-of-support warnings (`Get-WindowsUpdateComplianceReport`)
* **Multi-Admin Approval (MAA)** — MAA policy coverage, approver resolution, and request analytics (`Get-AppProtectionComplianceReport`)
* **Daily tenant HTML** — `Export-IntuneDashboard (v2.0+) for the integrated tenant report` — designed to be scheduled.

All workstation scripts support interactive sign-in (via `MgGraphCommunity` for WAM-free flow) and unattended app-only authentication via `-TenantId` / `-ClientId` with certificate or secret.

---

# ✨ Core Features

### 🔹 Tenant-Wide Graph Reporting
* Every script pages the beta Graph endpoint with 429/ throttling backoff and 100 ms inter-call delays
* Selects only the fields the report consumes and wraps single-result collections in `@()` for accurate counts

### 🔹 Actionable CSV + HTML
* Machine-readable CSVs for Excel/Power BI and operator-friendly HTML dashboards with summary statistics
* HTML template (`Report-Template.html`) with collapsible sections, Expand/Collapse All, and `id="t01"` table styling

### 🔹 Health Scoring with Context
* Apple tokens, connectors, and certificates scored **Healthy / Warning / Critical / NotConfigured** — stale sync (>7 days) and expiry windows (30/90/180 days) surface silent failures before enrollment or app install breaks
* Certificate profiles decode embedded root certificates locally to read the real `NotAfter` date

### 🔹 Enterprise Logging & Resilience
* Structured, timestamped logging to `C:\ProgramData\<SolutionName>\Logs\` with banner and level colors
* Per-device / per-policy errors are isolated — one bad device never aborts the whole report

### 🔹 Automation-Ready
* Portal-safe boolean parameters (`"true"/"false"/"1"/"0"`) for Azure Automation compatibility
* App-only auth (`TenantId` + `ClientId` + `ClientSecret` or `CertificateThumbprint`) for unattended schedules; `-ForceModuleInstall` and `-OutputPath` anchoring beside the script

---

# 📂 Project Structure

```text
Intune-Reporting-Tools
│
├── Test-AppleTokenValidity.ps1
├── Test-BitLockerKeys.ps1
├── Test-CertificateProfileExpiry.ps1
├── Test-ConnectorHealth.ps1
├── Test-FileVaultKeys.ps1
├── Test-PolicyChanges.ps1
├── Test-UnassignedPolicies.ps1
├── Export-IntuneAuditLogs.ps1
├── Get-AppProtectionComplianceReport.ps1
├── Get-CompliancePolicyCoverage.ps1
├── Get-DeviceComplianceReport.ps1
├── Get-EndpointAnalyticsReport.ps1
├── Get-NonCompliantDevices.ps1
├── Get-WindowsUpdateComplianceReport.ps1
├── Get-DailyTenantReport/
│   ├── Get-DailyTenantReport.ps1
│   └── Report-Template.html
└── README.md
```

---

# 📜 Scripts Included

| Script | Purpose | Graph Permissions | Run Context |
| ------ | ------- | ----------------- | ----------- |
| `Test-AppleTokenValidity.ps1` | Monitors Apple DEP tokens and Apple Push Notification Certificates — validity, expiration dates (DEP/APNs are 1-year), and sync status; flags expired/expiring/failed-sync items and optionally emails critical alerts. | `DeviceManagementServiceConfig.Read.All` + `Mail.Send` (only when `-SendEmailAlert`) | Workstation — interactive (MgGraphCommunity, WAM-free) or app-only (`TenantId`/`ClientId` + secret/cert); CSV report |
| `Test-BitLockerKeys.ps1` | Verifies that every Windows managed device has a BitLocker recovery key escrowed in Entra ID (via `informationProtection/bitlocker/recoveryKeys?$filter=deviceId`); reports compliance % and key counts with per-device 429 retry. | `DeviceManagementManagedDevices.Read.All`, `BitlockerKey.ReadBasic.All` | Workstation — interactive or app-only; CSV (+ optional JSON) |
| `Test-CertificateProfileExpiry.ps1` | Inventories SCEP, PKCS, and trusted-root certificate profiles — validity-period settings, assignment state, per-profile deployment errors, and decoded embedded root-certificate expiry. | `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only; console + optional CSV |
| `Test-ConnectorHealth.ps1` | Single health report for all tenant connectors — Apple APNs/DEP/VPP expiry & sync, Managed Google Play binding & app-sync, NDES, certificate connectors, and Mobile Threat Defense partner heartbeat; each connector scored Healthy/Warning/Critical/NotConfigured. | `DeviceManagementServiceConfig.Read.All`, `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All` | Workstation — interactive or app-only; console + optional CSV |
| `Test-FileVaultKeys.ps1` | Verifies that every macOS managed device has a FileVault recovery key stored in Intune via `managedDevices('{id}')/getFileVaultKey`; handles personal-device and 403/404 responses correctly. Requires privileged operation scope. | `DeviceManagementManagedDevices.PrivilegedOperations.All`, `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only; CSV (+ optional JSON) |
| `Test-PolicyChanges.ps1` | Surfaces recent Intune policy changes from `deviceManagement/auditEvents` (category `DeviceConfiguration`) filtered to `DeviceManagementConfigurationPolicy` activity types; optional email alert for changes. | `DeviceManagementApps.Read.All`, `Mail.Send` (only when `-SendEmailAlert`) | Workstation — interactive or app-only; CSV export of last 5 changes |
| `Test-UnassignedPolicies.ps1` | Finds device configuration, Settings Catalog, and Administrative Template (groupPolicyConfigurations) policies with zero assignments; risk-ranks results (security/compliance = High). | `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only; CSV |
| `Export-IntuneAuditLogs.ps1` | Retrieves and displays Intune audit log entries with filtering by date range, user, activity, category, and result; supports CSV and HTML export with auto-open. Uses beta `deviceManagement/auditEvents`. | `DeviceManagementApps.Read.All`, `DeviceManagementConfiguration.Read.All`, `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only; console + CSV/HTML |
| `Get-AppProtectionComplianceReport.ps1` | **Multi-Admin Approval (MAA) Compliance Dashboard** — inventories MAA policies, operationApprovalRequests, protectable resources (apps/scripts/configurationPolicies/RBAC), and Intune admins via transitive group membership; computes coverage %, approval-rate and approval-time analytics; emits interactive HTML dashboard + CSVs. | `DeviceManagementConfiguration.Read.All`, `DeviceManagementApps.Read.All`, `DeviceManagementManagedDevices.Read.All`, `DeviceManagementRBAC.Read.All`, `DeviceManagementScripts.Read.All`, `Directory.Read.All` | Workstation — interactive (MgGraphCommunity) or app-only; HTML dashboard + CSVs |
| `Get-CompliancePolicyCoverage.ps1` | Compares enrolled device platforms against platforms targeted by *assigned* compliance policies; flags platforms with devices but no assigned policy (devices silently pass Conditional Access when the tenant is set to Compliant) and lists unassigned policies. | `DeviceManagementConfiguration.Read.All`, `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only; console + optional CSV |
| `Get-DeviceComplianceReport.ps1` | Builds a per-device compliance report: overall Compliant/Non-Compliant/Unknown, compliant vs non-compliant policy counts via `deviceCompliancePolicyStates`, days since last sync, and stale-device detection; exports CSV + HTML. | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only; CSV + HTML |
| `Get-EndpointAnalyticsReport.ps1` | Collects Endpoint Analytics from beta `userExperienceAnalytics*` endpoints — device scores, startup performance (core + Group Policy boot time), app health (crash counts), battery health (max capacity, battery age), and Work From Anywhere metrics; exports per-category CSVs + summary HTML. | `DeviceManagementManagedDevices.Read.All` | Workstation — interactive or app-only; multiple CSVs + summary HTML (+ optional JSON) |
| `Get-NonCompliantDevices.ps1` | Enumerates every device whose `complianceState` matches the requested states (default `noncompliant`) and drills into `deviceCompliancePolicyStates` → `settingStates` to surface the exact failing setting, owning policy, value, and error code; one CSV row per failing setting with placeholder rows for unevaluated devices. | `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only; CSV + HTML |
| `Get-WindowsUpdateComplianceReport.ps1` | Inventories Windows Update deployment: update rings (`windowsUpdateForBusinessConfiguration`) with per-device success/error counts via `deviceStatuses`, feature update profiles with target version and end-of-support date, expedited quality update profiles, and driver update profiles; flags unassigned and error states. | `DeviceManagementConfiguration.Read.All` | Workstation — interactive or app-only; console + optional CSV |
| `Get-DailyTenantReport\Get-DailyTenantReport.ps1` (+ `Report-Template.html`) | Generates a comprehensive **daily HTML health report** — updated Win32 apps, admin audit events, unused/skus & stale-user/duplicate license waste, Secure Score, non-compliant device reasons, unused Windows 365 Cloud PCs, failed Entra sign-ins, failed app installs, app protection (MAM) issues, Apple push/VPP/DEP expiry, outdated Windows versions (scraped release information), Defender/malware & firewall posture, feature/quality/driver update errors, deployment status, stale Entra devices, service health issues/messages/overview, and full connector status — by replacing `$SectionNHead`/`$SectionNBody` placeholders in `Report-Template.html` and saving `Get-DailyTenantReport-dd-MM-yyyy-HH-mm-ss.html` beside the script. Template includes collapsible sections and `table#t01` styling. | App-secret mode: delegated via `https://graph.microsoft.com/.default` (app permissions granted on the registration). Interactive mode requests: `AuditLog.Read.All`, `CloudPC.ReadWrite.All`, `DeviceManagementApps.ReadWrite.All`, `DeviceManagementConfiguration.ReadWrite.All`, `DeviceManagementManagedDevices.ReadWrite.All`, `DeviceManagementRBAC.Read.All`, `DeviceManagementRBAC.ReadWrite.All`, `DeviceManagementServiceConfig.ReadWrite.All`, `Directory.Read.All`, `Domain.Read.All`, `Domain.ReadWrite.All`, `Policy.ReadWrite.ConditionalAccess`, `Policy.ReadWrite.MobilityManagement`, `RoleAssignmentSchedule.ReadWrite.Directory`, `SecurityEvents.Read.All`, `User.ReadWrite.All`, `openid`, `profile`, `email`, `offline_access` | **Scheduled HTML report** — Task Scheduler / Azure Automation / service account (app-secret via `-Tenant`/`-ClientID`/`-ClientSecret`) or interactive workstation; requires `Report-Template.html` beside the script; writes `Get-DailyTenantReport-*.html` + transient temp files (`report*.txt`, `appreport.txt`, `fwreport.txt`, etc.) beside the script |

---

# ⚙️ Requirements

### Operating System
* Windows 10 / Windows 11 (all scripts declare `.PLATFORM Windows`)

### PowerShell
* PowerShell **5.1 or later** (`#Requires -Version 5.1` on every script)

### Microsoft Graph
* `Microsoft.Graph.Authentication` module (auto-installed if missing; `MgGraphCommunity` is used for WAM-free interactive sign-in)
* Permissions are consented per script as shown in the table above — least-privilege is the default; `Mail.Send` is only requested when email alerts are enabled
* Beta Graph endpoints are used — most Intune reporting surfaces are not exposed on `v1.0`

### Authentication
* **Interactive:** `Connect-MgGraph` / `Connect-MgGraphCommunity` with delegated scopes (browser sign-in)
* **Unattended:** `TenantId` + `ClientId` + `ClientSecret` *or* `CertificateThumbprint` — suitable for Azure Automation Runbooks and scheduled tasks

### Logging
* **This category (workstation tools):** `C:\ProgramData\<SolutionName>\Logs\<SolutionName>_yyyyMMdd_HHmmss.log` — e.g. `C:\ProgramData\check-bitlocker-keys\Logs\`
* **Proactive Remediations** in this repo use a different path: `<SystemDrive>\IntuneLogs\<SolutionName>\` (e.g. `C:\IntuneLogs\Disable-FastStartup\`) — do not confuse the two when collecting logs

---

# 🛡 Operational Notes

* **Certificate / Apple token lead time:** Trusted-root and Apple DEP/APNs/VPP artifacts expire after one year. Default warning windows are 30 days (`Test-AppleTokenValidity`, `Test-ConnectorHealth`) and 90 days (`Test-CertificateProfileExpiry`); Windows feature-update profiles default to 180 days end-of-support warning. Tune via `-ExpiryWarningDays` / `-EndOfSupportWarningDays` / `-ExpirationWarningDays` for renewal lead time.
* **Audit log retention:** Intune audit events (`deviceManagement/auditEvents`) are retained for **30 days**. `Export-IntuneAuditLogs` caps `-DaysBack` at 30 and `-NumberOfEntries` at 1000; `Test-PolicyChanges` defaults to 30 days and pages `category eq 'DeviceConfiguration'` — older changes must be archived externally.
* **MAA pending-request volume:** `Get-AppProtectionComplianceReport` pulls all `operationApprovalRequests` and filters by `-DaysToAnalyze` (default 30). Tenants with heavy MAA usage can see large pending queues; high pending counts and average approval time >72 h should trigger process review. The report tolerates partial resource inventory — coverage math degrades gracefully when a category cannot be enumerated.
* **BitLocker / FileVault volume:** Per-device key checks are paced at 100 ms with 429 retry and 60 s backoff. Large estates (thousands of devices) will take several minutes; use `-ShowProgress` and `-OnlyShowMissing` to reduce noise.
* **Daily tenant report scheduling:** `Get-DailyTenantReport.ps1` queries live tenant data and scrapes Microsoft release pages for supported Windows builds. Schedule it via Task Scheduler or a service account rather than running ad-hoc. Keep `Report-Template.html` beside the script — its `$SectionNHead`/`$SectionNBody` placeholders are replaced at runtime and transient files (`report*.txt`, `appreport.txt`, `fwreport.txt`, `featureupdates.txt`, `expeditedupdates.txt`, `driverupdates.txt`) are created and deleted beside the script.

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

