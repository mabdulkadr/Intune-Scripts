# Restart-Windows-Update-Service

![Scope](https://img.shields.io/static/v1?label=scope&message=Intune&color=blue)
![Mode](https://img.shields.io/static/v1?label=mode&message=CLI&color=lightgrey)
![Scripts](https://img.shields.io/static/v1?label=scripts&message=2&color=green)
![Pattern](https://img.shields.io/static/v1?label=pattern&message=DetectionOnly&color=blue)
![Tech](https://img.shields.io/static/v1?label=tech&message=Intune%2BServices&color=blue)

---

## 📖 Overview
This folder contains **2 PowerShell script(s)**. The documentation below is generated from actual script content and includes technical behavior, dependencies, integration points, and exit-code patterns.


## ✨ Features
- Folder scope: `Intune`
- Execution mode: `CLI`
- Scripts detected: **2**
- Path: `Intune-Scripts\Intune - Remediation Scripts\Restart-Windows-Update-Service\README.md`


## ⚙️ Requirements
- Windows PowerShell 5.1 or newer.
- Permissions aligned with script operations (file system, services, tasks, registry, API).
- Required modules and APIs are listed per script in Technical Details.

## 📂 Script Inventory
| File | Type | Synopsis |
|---|---|---|
| `detect-wu-service.ps1` | Detection | Detect compliance state for wu service. |
| `restart-wu-service.ps1` | Restart | Perform restart workflow for wu service. |


## 🔍 Technical Details
### `detect-wu-service.ps1`
- **Functional Type:** Detection
- **Purpose:** Detect compliance state for wu service.
- **Technical Description:** This detection script evaluates wu service and returns compliance status. It is intended for Intune Proactive Remediations or scheduled automation. Exit codes: - Exit 1: Not Compliant (remediation should run) - Exit 0: Compliant
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Restart-Windows-Update-Service\detect-wu-service.ps1`
- **Observed Exit Codes:** `0`, `1`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.
  - Permissions to query or manage Windows services (Get/Set/Start/Stop-Service).

#### Key Cmdlets/Commands
- `Get-Service`
- `Where-Object`
- `Write-Host`

### `restart-wu-service.ps1`
- **Functional Type:** Restart
- **Purpose:** Perform restart workflow for wu service.
- **Technical Description:** This script executes restart-related actions for wu service. Review user-impact and scheduling requirements before execution. Exit codes: - Exit 0: Completed successfully - Exit 1: Failed or requires further action
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Restart-Windows-Update-Service\restart-wu-service.ps1`
- **Observed Exit Codes:** `0`, `1`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.
  - Permissions to query or manage Windows services (Get/Set/Start/Stop-Service).

#### Key Cmdlets/Commands
- `Restart-Service`


## 🚀 Usage
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\detect-wu-service.ps1
.\restart-wu-service.ps1
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

