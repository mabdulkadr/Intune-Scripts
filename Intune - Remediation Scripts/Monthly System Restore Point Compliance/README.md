# Monthly System Restore Point Compliance

![Scope](https://img.shields.io/static/v1?label=scope&message=Intune&color=blue)
![Mode](https://img.shields.io/static/v1?label=mode&message=CLI&color=lightgrey)
![Scripts](https://img.shields.io/static/v1?label=scripts&message=2&color=green)
![Pattern](https://img.shields.io/static/v1?label=pattern&message=Detection%2BRemediation&color=brightgreen)
![Tech](https://img.shields.io/static/v1?label=tech&message=Intune%2BRegistry&color=blue)

---

## 📖 Overview
This folder contains **2 PowerShell script(s)**. The documentation below is generated from actual script content and includes technical behavior, dependencies, integration points, and exit-code patterns.


## ✨ Features
- Folder scope: `Intune`
- Execution mode: `CLI`
- Scripts detected: **2**
- Path: `Intune-Scripts\Intune - Remediation Scripts\Monthly System Restore Point Compliance\README.md`
- Proactive Remediations pattern: Detection + Remediation pair is available.


## ⚙️ Requirements
- Windows PowerShell 5.1 or newer.
- Permissions aligned with script operations (file system, services, tasks, registry, API).
- Required modules and APIs are listed per script in Technical Details.

## 📂 Script Inventory
| File | Type | Synopsis |
|---|---|---|
| `Detect-MonthlyRestorePoint.ps1` | Detection | Detect compliance state for MonthlyRestorePoint. |
| `Remediate-MonthlyRestorePoint.ps1` | Remediation | Remediate MonthlyRestorePoint based on defined conditions. |


## 🔍 Technical Details
### `Detect-MonthlyRestorePoint.ps1`
- **Functional Type:** Detection
- **Purpose:** Detect compliance state for MonthlyRestorePoint.
- **Technical Description:** This detection script evaluates MonthlyRestorePoint and returns compliance status. It is intended for Intune Proactive Remediations or scheduled automation. Exit codes: - Exit 1: Not Compliant (remediation should run) - Exit 0: Compliant
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Monthly System Restore Point Compliance\Detect-MonthlyRestorePoint.ps1`
- **Observed Exit Codes:** `0`, `1`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.

#### Internal Functions
- `Convert-WmiDate`
- `Try-ParseDate`

#### Key Cmdlets/Commands
- `Convert-WmiDate`
- `ForEach-Object`
- `Get-CimInstance`
- `Get-ComputerRestorePoint`
- `Get-Date`
- `Group-Object`
- `New-Object`
- `Select-Object`
- `Sort-Object`
- `Try-ParseDate`
- `Where-Object`
- `Write-Output`

### `Remediate-MonthlyRestorePoint.ps1`
- **Functional Type:** Remediation
- **Purpose:** Remediate MonthlyRestorePoint based on defined conditions.
- **Technical Description:** This remediation script applies corrective actions for MonthlyRestorePoint. Use with Intune Proactive Remediations or on-demand execution. Exit codes: - Exit 0: Completed successfully - Exit 1: Failed or requires further action
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Monthly System Restore Point Compliance\Remediate-MonthlyRestorePoint.ps1`
- **Observed Exit Codes:** `0`, `1`, `2`, `3`, `4`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.

#### Internal Functions
- `Convert-WmiDate`
- `Ensure-SystemProtection`
- `Get-AllRestorePoints`
- `New-MonthlyRestorePoint`
- `Test-MonthlyRestorePoint`
- `Try-ParseDate`
- `Write-Log`

#### Key Cmdlets/Commands
- `Add-Content`
- `Checkpoint-Computer`
- `Convert-WmiDate`
- `Enable-ComputerRestore`
- `Ensure-SystemProtection`
- `Get-AllRestorePoints`
- `Get-CimInstance`
- `Get-ComputerRestorePoint`
- `Get-Date`
- `Get-ItemProperty`
- `Join-Path`
- `New-Item`
- `New-MonthlyRestorePoint`
- `New-Object`
- `Out-Null`
- *(+10 additional commands found in script)*

#### Registry Touchpoints
- `HKLM:\Software\Microsoft\Windows NT\CurrentVersion\SystemRestore`


## 🚀 Usage
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Detect-MonthlyRestorePoint.ps1
.\Remediate-MonthlyRestorePoint.ps1
```


## 🛡️ Operational Notes
- ✅ Validate scripts in a pilot environment before production rollout.
- 🔎 Review execution logs (if present) and verify exit codes match expected behavior.
- ⚠️ For Intune use cases, validate assignment context and **Run this script using logged-on credentials** configuration.


## 🧷 Compatibility and Revision
- Documentation last updated: **2026-02-15**
- This README is standardized and generated from local script analysis to keep documentation aligned with implementation.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## ⚠️ Disclaimer

This script is provided **as-is** without warranty.
The author is **not responsible** for unintended modifications or data loss.
Always test thoroughly before deploying in production.

