<div align="center">

# 🛡️ Intune Scripts — Enterprise Library

**Enterprise-Grade Intune Automation — Detection, Remediation & Reporting**

Production-grade collection of detection/remediation pairs, compliance checks, tenant reports, and device lifecycle operations for Microsoft Intune. Deploy via Intune or run from any admin workstation.

[![Intune](https://img.shields.io/badge/Microsoft-Intune%20%2B%20Graph-0078D4?style=for-the-badge)](#-overview)
[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20macOS-0F172A?style=for-the-badge)](#%EF%B8%8F-requirements)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)
[![Version](https://img.shields.io/badge/Version-2.1-334155?style=for-the-badge)](#-overview)

[Overview](#-overview) • [Categories](#-categories) • [Quick Start](#-quick-start) • [Requirements](#%EF%B8%8F-requirements) • [License](#-license)

</div>

---

# 📖 Overview

**Intune Scripts — Enterprise Library** is a production-ready, **Azure-free** repository of **PowerShell 5.1 and macOS shell automation for Microsoft Intune and Microsoft Graph**.

The repository consolidates the original remediation catalog with the adapted IntuneAutomation collection into a single functional taxonomy. Every script runs in exactly two contexts: **deployed by Intune** (proactive remediations, custom compliance, shell script profiles) or **standalone from an admin workstation** via interactive or app-only Graph sign-in. All Azure Automation runbooks, Managed Identity branches, and deployment templates have been removed.

Designed for enterprise scale: standardized headers, structured logging, deterministic exit codes, and a README per solution folder so each package is deployable independently.

---

# ✨ Core Features

### 🔹 Unified Intune Automation Library
* **Proactive remediations** — paired `detect-` / `remediate-` packages for cleanup, repair, hardening, and notifications
* **Custom compliance** — JSON-emitting discovery scripts for Intune custom compliance policies
* **Tenant & reporting tools** — backup/restore, assignment auditing, compliance and update reporting, and governance
* **Device operations** — bulk group management, Autopilot cleanup, sync/restart/wipe, and readiness reporting
* **Security tools** — BitLocker/LAPS/Defender/Firewall posture and rotation
* **macOS hygiene** — 7 bash checks for FileVault, XProtect, MAU, and privileged access

### 🔹 Production Focus
* PowerShell **5.1 contract** — no aliases, typed exceptions, no empty catches
* Canonical rich header (`.SYNOPSIS` → `.NOTES`, `.REMEDIATIONTYPE` / `.PAIRSCRIPT` on pairs, real `.PERMISSIONS`)
* Verbatim logging block (`Initialize-Log` / `Write-Banner` / `Write-Log` / `Finish-Script`) to `<SystemDrive>\IntuneLogs\<Solution>\` or `C:\ProgramData\<ScriptName>\Logs`
* Exit-code contract: detection `0` compliant / `1` non-compliant / `2` error; remediation `0` success / `1` failure / `2` error with pre-check → fix → post-verify → JSON output

### 🔹 Azure-Free, Workstation-First
* No Azure Automation, no Managed Identity, no ARM templates
* Graph tools support **interactive sign-in** (with `Microsoft.Graph` / `MgGraphCommunity` WAM-free fallback) and **app-only** (`-TenantId` + `-ClientId` + `-ClientSecret` or `-CertificateThumbprint`)
* Scopes, URIs, and business logic preserved from upstream — only the auth shell was unified

---

# 📂 Project Structure

```text
Intune-Scripts-main/
│
├── Intune-Proactive-Remediations/      68 pairs · 205 files (138 .ps1 + READMEs)  # +6 NEW in v2.1 (CA 2023, Lenovo, LLMNR, TeamsCache, Battery, LAPS drift)
│   └── <Solution>/  detect-<Solution>.ps1 · remediate-<Solution>.ps1 · README.md
│       NEW: SecureBoot-CA2023-Update · Enable-SecureBoot-Lenovo · Disable-LLMNR-NetBIOS · Clear-TeamsCache · Get-BatteryHealth · Test-WindowsLapsDrift
│
├── Intune-Custom-Compliance/           3 compliance packages + generator GUI · 13 files  # +1 NEW (Bitlocker-EncryptionMethod)
│   ├── Get-AppPresenceCompliance/
│   ├── Get-AppVersionCompliance/
│   ├── Bitlocker-EncryptionMethod/     # NEW — XTS-AES 128/256 enforcement
│   └── CustomCompliancePolicyGeneratorGUI/
│
├── Intune-Security-Tools/              8 tools · 8 .ps1  # +1 NEW (Test-AsrRulesCoverage)
│   ├── Backup-BitLockerKeysToKeyVault.ps1
│   ├── Get-DefenderStatusReport.ps1
│   ├── Get-FirewallAsrStatus.ps1
│   ├── Get-IntuneBitLockerKeys.ps1          (from IntuneToolKit)
│   ├── Get-WindowsLapsAudit.ps1
│   ├── Rotate-BitLockerRecoveryKeys.ps1
│   ├── Rotate-MacOsFileVaultPasswords.ps1
│   └── Test-AsrRulesCoverage/          # NEW — ASR 18-rule GAP vs 25H2 baseline
│       └── Test-AsrRulesCoverage.ps1
│
├── Intune-Reporting-Tools/             37 reports (curated + adapted) + integrated dashboard suite · 37 .ps1 + READMEs  # +1 NEW (Hotpatch)
│   ├── Check-* / Get-* health & compliance suites (15 curated)
│   ├── Export-*/Find-*/Get-Entra*/Get-Intune* audit & inventory suites (31 from IntuneToolKit)
│   ├── Export-IntuneDashboard/           (integrated tenant dashboard — merged with former Get-DailyTenantReport in v2.0)
│   └── Get-HotpatchReadiness/          # NEW — Hotpatch eligibility (VBS/SKU/Build 26100+)
│       └── Get-HotpatchReadiness.ps1
│
├── Intune-Tenant-Tools/                7 standalone + 2 suites · 11 files
│   ├── Backup-IntuneConfiguration.ps1  · Restore-IntuneConfiguration.ps1
│   ├── Get-AssignmentFilterAudit.ps1   · Get-AssignmentMatrix.ps1  · Get-GroupAssignments.ps1
│   ├── Compare-PolicyDrift.ps1         · Get-IntuneRoleAssignments.ps1
│   ├── Approve-IntuneDriverUpdates/    (bulk driver approval suite)
│   └── Invoke-BulkRemediation/         (on-demand bulk remediation suite)
│
├── Intune-Device-Operations/           17 tools (14 isolated + 2 suites + 1 from IntuneToolKit) · 17 .ps1
│   ├── Get-StaleDevices.ps1  · Get-DevicesByScopeTag.ps1  · Get-Windows11Readiness.ps1
│   ├── Add-DevicesToGroupsFromCsv.ps1  · New-AppBasedGroups.ps1  · Rename-DevicesFromCsv.ps1
│   ├── Repair-PrimaryUserAssignment.ps1  · Sync-IntuneDevices.ps1  · Restart-IntuneDevices.ps1
│   ├── Remove-StaleAutopilotDevices.ps1  · Remove-DuplicateDeviceRecords.ps1  · Invoke-DeviceWipe.ps1
│   ├── Invoke-FullIntuneClientRepairEngine.ps1
│   ├── Set-DeliveryOptimization/        (suite)
│   └── Sync-AllIntuneDevices/          (suite)
│
├── Intune-Diagnostics/                 4 tools · 4 .ps1  # +1 NEW (Get-ImeDiagnostics)
│   ├── Collect-DeviceDiagnostics.ps1
│   ├── Get-DeviceCheckinHealth.ps1
│   ├── Get-EnrollmentFailureReport.ps1
│   └── Get-ImeDiagnostics/             # NEW — IME log timeline (Carbon Dark HTML)
│       └── Get-ImeDiagnostics.ps1
│
├── Intune-App-Tools/                   6 tools + 2 suites · 10 files
│   ├── Get-ApplicationInventory.ps1  · Get-AppInstallStatus.ps1  · Get-AppAssignmentConflicts.ps1
│   ├── Get-DuplicateApplications.ps1  · Get-VppLicenseReport.ps1  · Remove-OrphanedApps.ps1
│   ├── Repair-CompanyPortal/           (suite)
│   └── Invoke-Win32AppAutoDeployer/             (Win32 app auto-deployer suite)
│
├── Intune-macOS/                       8 shell checks · 8 .sh (bash/zsh)  # +1 NEW (Platform SSO GA May 2026)
│   ├── check-applecare-warranty-status.sh
│   ├── check-available-msupdate-updates.sh
│   ├── check-msupdate-status.sh
│   ├── check-network-requirements.sh
│   ├── check-xprotect-status.sh
│   ├── check-platform-sso-status.sh    # NEW — Platform SSO GA
│   ├── last-reboot.sh
│   └── local-admins.sh
│
├── ROADMAP.md                          Expansion roadmap (Secure Boot CA 2023, Autopilot, hardening)
└── README.md                           This file (master index)
```

> **Taxonomy note:** The 8 core PowerShell categories above match the restructure plan; **Intune-macOS** is the 9th category (bash/zsh) that completes the cross-platform library. Counts reflect the current checkout and are updated as packages are added.

---

# 🧭 Categories

| Category | Contents | Count | Docs |
| -------- | -------- | ----- | ---- |
| [Intune-Proactive-Remediations](Intune-Proactive-Remediations/README.md) | Paired detection/remediation packages (cleanup, repair, hardening, notifications, status) | **68 pairs** · 205 files *(+6 NEW: CA 2023, Lenovo, LLMNR, TeamsCache, Battery, LAPS drift)* | [README](Intune-Proactive-Remediations/README.md) |
| [Intune-Custom-Compliance](Intune-Custom-Compliance/README.md) | Custom compliance discovery scripts emitting JSON (App Presence, App Version) + GUI generator | **3 packages** + GUI · 13 files *(+1 NEW: BitLocker EncryptionMethod)* | [README](Intune-Custom-Compliance/README.md) |
| [Intune-Security-Tools](Intune-Security-Tools/) | BitLocker / LAPS / Key Vault / Defender / Firewall & ASR posture and rotation | **8 tools** *(+1 NEW: ASR Coverage)* | [Folder](Intune-Security-Tools/) |
| [Intune-Reporting-Tools](Intune-Reporting-Tools/) | Tenant-wide reports: compliance, audit logs, Endpoint Analytics, Entra audits, device inventory/timeline, update rings & compliance, policy coverage | **37 tools** + integrated dashboard *(+1 NEW: Hotpatch Readiness)* | [Folder](Intune-Reporting-Tools/) |
| [Intune-Tenant-Tools](Intune-Tenant-Tools/) | Backup/restore, assignment & filter audits, drift comparison, RBAC, bulk remediation & driver approval | **9 tools** (7 + 2 suites) · 11 files | [Folder](Intune-Tenant-Tools/) |
| [Intune-Device-Operations](Intune-Device-Operations/) | Remote device actions & lifecycle: group bulk ops, Autopilot cleanup, sync/restart/wipe, readiness, DO, bulk actions (ToolKit) | **17 tools** (14 isolated + 2 suites + 1 from IntuneToolKit) | [Folder](Intune-Device-Operations/) |
| [Intune-Diagnostics](Intune-Diagnostics/) | Health checks & failure analysis: diagnostics collection, check-in health, enrollment failures | **4 tools** *(+1 NEW: IME Diagnostics)* | [Folder](Intune-Diagnostics/) |
| [Intune-App-Tools](Intune-App-Tools/) | App inventory, assignment conflicts, duplicates, orphan cleanup, VPP licensing, Win32 deployer, Company Portal repair | **8 tools** (6 + 2 suites) · 10 files | [Folder](Intune-App-Tools/) |
| [Intune-macOS](Intune-macOS/README.md) | macOS shell checks: warranty, MAU status/updates, network prerequisites, XProtect/SIP/Gatekeeper/FileVault, uptime, local admins | **8 scripts** · 8 .sh *(+1 NEW: Platform SSO GA)* | [README](Intune-macOS/README.md) |

---

# 🚀 Quick Start

## Workflow A — Deploy a remediation pair via Intune

For any folder under `Intune-Proactive-Remediations/` (e.g., `Disable-FastStartup`):

1. Open the package's own `README.md` — it is the authoritative deployment guide.
2. In Intune: **Devices > Scripts and remediations > Create > Proactive remediations**.
3. Upload **Detection script**: `detect-<Solution>.ps1`.
4. Upload **Remediation script**: `remediate-<Solution>.ps1`.
5. Set **Run this script using the logged-on credentials**: **No** (SYSTEM), **Enforce script signature check**: **No**, **Run script in 64-bit PowerShell**: **Yes**.
6. Assign to a **staging device group**, set schedule (e.g., hourly), test, then roll out to production.

> Detection `0` = compliant (no remediation), `1` = non-compliant (triggers remediation), `2` = error (never treated as non-compliant). Remediation emits structured JSON and verifies its own result.

```powershell
# Optional local smoke test (read-only detection)
Set-ExecutionPolicy Bypass -Scope Process -Force
.\Intune-Proactive-Remediations\Disable-FastStartup\detect-Disable-FastStartup.ps1
$LASTEXITCODE  # 0 compliant, 1 non-compliant, 2 error
```

## Workflow B — Run a workstation tool (Graph, no Azure)

For tenant/reporting/device tools (e.g., `Get-StaleDevices.ps1`, `Backup-IntuneConfiguration.ps1`):

**Mode 1 — Interactive sign-in (default):**

```powershell
Set-ExecutionPolicy Bypass -Scope Process -Force
Install-Module Microsoft.Graph -Scope CurrentUser  # first time only

.\Intune-Device-Operations\Get-StaleDevices.ps1 -DaysInactive 90
.\Intune-Tenant-Tools\Backup-IntuneConfiguration.ps1 -OutputPath C:\Temp\IntuneBackup
```

On PowerShell 5.1 the tools fall back to `MgGraphCommunity` for WAM-free sign-in when available; otherwise they use the standard `Connect-MgGraph` browser flow with the scopes declared in the script header.

**Mode 2 — App-only (unattended, with -TenantId):**

```powershell
# Client secret
.\Intune-Reporting-Tools\Get-DeviceComplianceReport.ps1 `
  -TenantId "11111111-1111-1111-1111-111111111111" `
  -ClientId "22222222-2222-2222-2222-222222222222" `
  -ClientSecret (Read-Host -AsSecureString "Client secret")

# Certificate thumbprint
.\Intune-Device-Operations\Get-StaleDevices.ps1 `
  -TenantId "11111111-1111-1111-1111-111111111111" `
  -ClientId "22222222-2222-2222-2222-222222222222" `
  -CertificateThumbprint "ABCDEF1234567890ABCDEF1234567890ABCDEF12"
```

App-only uses the `.default` scope and works on any machine where the certificate/secret is available — ideal for scheduled tasks.

**macOS variant:**

```bash
chmod +x ./Intune-macOS/check-xprotect-status.sh
./Intune-macOS/check-xprotect-status.sh
shellcheck ./Intune-macOS/*.sh
```

---

# ⚙️ Requirements

### Environment
* Windows PowerShell **5.1 or later** (PowerShell 7 supported for workstation tools where noted)
* **Administrator privileges** on the admin workstation for Graph tools; **SYSTEM context** when deployed via Intune
* Microsoft Intune tenant — no Azure subscription or Automation account required
* macOS **10.15+** with `bash 3.2+` or `zsh` for `Intune-macOS` checks

### Modules (workstation tools only)

```powershell
Install-Module Microsoft.Graph -Scope CurrentUser
```

Optional per script (declared in each header's `.PERMISSIONS`):

```powershell
Install-Module Microsoft.Graph.Authentication  # fallback handled automatically
```

Intune-deployed remediation and compliance scripts require **no Graph modules** — they run in SYSTEM context with local logging only.

### Permissions
* Each script's header lists the exact Graph scopes or local privileges required (e.g., `DeviceManagementManagedDevices.Read.All`, `DeviceManagementConfiguration.Read.All`, `AuditLog.Read.All`, or local `SYSTEM`).
* For app-only runs, grant the declared **Application** permissions to the Entra app registration and admin-consent them.

---

# 🛡 Operational Notes

* Use each package's own `README.md` as the authoritative deployment guide — it documents exit codes, logging paths, and Intune assignment settings.
* Test every script in a **staging device group** before tenant-wide assignment.
* Detection errors exit with code `2` so Intune never evaluates a crashed script as non-compliance; remediation verifies with pre-check → fix → post-verify and structured JSON output.
* Logs: endpoint pairs under `<SystemDrive>\IntuneLogs\<Solution>\`; workstation tools under `C:\ProgramData\<ScriptName>\Logs` (see each script's header).
* Destructive tools (`Invoke-DeviceWipe`, `Remove-StaleAutopilotDevices`, `Remove-DuplicateDeviceRecords`, `Remove-OrphanedApps`) are flagged with ⚠ in their READMEs — confirm scope and backup before use.
* **Apple Silicon vs Intel / Rosetta (macOS):** All `Intune-macOS` checks use universal tooling (`sysctl`, `dscl`, `sw_vers`, `nc`, `csrutil`, `spctl`, `fdesetup`) and run identically on both architectures; no Rosetta dependency. MAU checks invoke the native `msupdate` binary for the host arch.
* No Azure dependencies remain — if a script still references Managed Identity or Automation variables, treat it as a bug and report it.

### Attribution

This library consolidates the original remediation catalog with monitoring and automation shells adapted from **Ugur Koc / IntuneAutomation** ([github.com/ugurkocde/IntuneAutomation](https://github.com/ugurkocde/IntuneAutomation), MIT). Original `.AUTHOR` fields and `CHANGELOG` entries are preserved on adapted files; catalog contributors from the pre-restructure repository remain credited in per-folder READMEs.

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

