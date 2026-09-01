<div align="center">

# 🗺️ Roadmap — Intune Scripts Library

**v2.1 shipped · v3.0 planned**

[![PowerShell](https://img.shields.io/badge/PowerShell-5.1%2B-5391FE?style=for-the-badge&logo=powershell&logoColor=white)](https://learn.microsoft.com/en-us/powershell/)
[![Platform](https://img.shields.io/badge/Platform-Windows%2010%2F11%20%7C%20macOS-0F172A?style=for-the-badge)](#-overview)
[![License](https://img.shields.io/badge/License-MIT-F59E0B?style=for-the-badge)](#-license)

</div>

---

# 📖 Overview

This roadmap tracks what shipped in **v2.1 (2026-08-31)** and what is planned for **v3.0**. It is the single source for expansion priorities after the 2025-2026 GitHub and Intune What’s New research.

---

# ✅ v2.1 — Shipped (2026-08-31)

**10 new scripts across 6 categories — the June 2026 Secure Boot deadline gap is now closed.**

| Category | New Script | Why |
| -------- | ---------- | --- |
| Remediation | `SecureBoot-CA2023-Update` (pair) | **P0** — 2011 certs expired June 2026, revocation Oct 2028. Provisions `AvailableUpdatePolicy=5944` |
| Remediation | `Enable-SecureBoot-Lenovo` (pair) | Fixes `Not Applicable` on Lenovo via WMI + BitLocker suspend |
| Remediation | `Disable-LLMNR-NetBIOS` (pair) | CIS L1 hardening, 25H2 baseline expectation |
| Remediation | `Clear-TeamsCache` (pair) | #1 ticket driver — classic + new Teams (`MSTeams_*`) across all profiles |
| Remediation | `Get-BatteryHealth` (pair) | Fleet battery degradation (<80%) — report-only with JSON + Event Log |
| Remediation | `Test-WindowsLapsDrift` (pair) | Legacy AdmPwd.dll vs Windows LAPS drift + Event 10011 |
| Diagnostics | `Get-ImeDiagnostics` (CLI) | IME log timeline → Carbon Dark HTML (Win32App/ESP/Remediation categories) |
| Security | `Test-AsrRulesCoverage` (CLI) | 18 ASR rules vs 25H2 baseline GAP analysis (Block/Audit/Not Configured) |
| Reporting | `Get-HotpatchReadiness` (CLI) | Hotpatch Default-ON May 2026: VBS + SKU + Build 26100 |
| Custom Compliance | `Bitlocker-EncryptionMethod` (discovery + JSON) | XTS-AES 128/256 enforcement for Conditional Access |
| macOS | `check-platform-sso-status` (sh) | Platform SSO GA May 2026 — successor to Enterprise SSO plug-in |

**Housekeeping in v2.1:**
- Added `.gitignore` (Reports/Logs/*.csv/*.html)
- Fixed `Intune-Proactive-Remediations/README.md` stale reference
- Master README bumped to **v2.1** with updated counts: 68 pairs, 47 reports, 4 diagnostics, 8 security, 3 compliance, 8 macOS

---

# 🔜 v3.0 — Planned (Q4 2026)

**Prioritized by operator impact and GitHub star demand.**

### P1 — Tenant Hygiene & Reporting
- [ ] `Get-AssignmentFilterHygiene.ps1` — unused filters + empty Entra groups (from JayRHa ManagementImprovements)
- [ ] `Get-PolicyConflictMatrix.ps1` — expand `Find-IntunePolicyConflict` to Settings Catalog vs Administrative Templates cross-conflict
- [ ] `Get-EntraPimAssignmentReport.ps1` — PIM eligible vs active + drift
- [ ] `Get-Windows365-CloudPC-Usage.ps1` — standalone W365 unused Cloud PC report (currently buried in DailyTenantReport)

### P1 — Device Lifecycle
- [ ] `Invoke-DeviceOffboarding.ps1` — 2026 Offboarding Agent flow: unenroll + wipe + Autopilot delete + Entra delete
- [ ] `Test-AutopilotPrerequisites.ps1` — network + TPM + NTP + profile (from JayRHa Check-AutopilotPrerequisites)
- [ ] `Get-Windows11-25H2-BaselineDrift.ps1` — compare tenant vs Microsoft 25H2 baseline (9 changes)

### P1 — Compliance & Security
- [ ] `Defender-Antivirus-Exclusions` custom compliance (from alexverboon)
- [ ] `Firewall-Auditing` custom compliance
- [ ] `Windows-Service/Application Identity` custom compliance

### P2 — Suite & UX
- [ ] Unified dashboard: merge `Export-IntuneDashboard` + `Get-DailyTenantReport` into one Carbon Dark HTML with KPI + charts (`templates/EnterpriseHtmlReport.template.ps1`)
- [ ] WPF Toolbox GUI (`Intune-Toolbox-GUI.ps1`) — Tailwind Slate, 6 most-used reports in one window
- [ ] `Intune-Linux/` folder — 3 shell checks for RHEL 9/10 LTS (Intune Linux SSO GA April 2026)
- [ ] GitHub Actions: `PSScriptAnalyzer` + `Test-ToolCompliance.ps1` on every PR

---

# 🧭 How to Contribute

1. Pick an unchecked item above and open an Issue: `Roadmap v3.0 — <script name>`
2. Copy the matching `templates/*.template.ps1` scaffold — keep header + logging + exit codes canonical
3. Run `scripts/Test-ToolCompliance.ps1 -ToolPath <file>` — zero FAIL before PR
4. PR must include `README.md` from `templates/readme-*.template.md`

---

## 👤 Author
**Mohammad Abdelkader Omar** — [@mabdulkadr](https://github.com/mabdulkadr) — [momar.tech](https://momar.tech)

## 📜 License
MIT

## ⚠ Disclaimer
Provided as-is. Test in staging before production.

---
<div align="center">

⭐ **If this skill saves you time, star the repo — it helps others find it.**

[Report an Issue](../../issues) · [momar.tech](https://momar.tech)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-FFDD00?style=for-the-badge&logo=buy-me-a-coffee&logoColor=black)](https://www.buymeacoffee.com/mabdulkadrx)

Built with [**PowerShell Enterprise Admin**](https://github.com/mabdulkadr/powershell-enterprise-admin-skill)

</div>
