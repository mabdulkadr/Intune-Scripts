# Disable Local Network Access Checks (Chrome & Edge)

![Scope](https://img.shields.io/static/v1?label=scope&message=Intune&color=blue)
![Mode](https://img.shields.io/static/v1?label=mode&message=CLI&color=lightgrey)
![Scripts](https://img.shields.io/static/v1?label=scripts&message=3&color=green)
![Pattern](https://img.shields.io/static/v1?label=pattern&message=Detection%2BRemediation&color=brightgreen)
![Tech](https://img.shields.io/static/v1?label=tech&message=Intune&color=blue)

---

## 📖 Overview
This folder contains **3 PowerShell script(s)**. The documentation below is generated from actual script content and includes technical behavior, dependencies, integration points, and exit-code patterns.


## ✨ Features
- Folder scope: `Intune`
- Execution mode: `CLI`
- Scripts detected: **3**
- Path: `Intune-Scripts\Intune - Remediation Scripts\Disable Local Network Access Checks (Chrome & Edge)\README.md`
- Proactive Remediations pattern: Detection + Remediation pair is available.


## ⚙️ Requirements
- Windows PowerShell 5.1 or newer.
- Permissions aligned with script operations (file system, services, tasks, registry, API).
- Required modules and APIs are listed per script in Technical Details.

## 📂 Script Inventory
| File | Type | Synopsis |
|---|---|---|
| `Detect-LNA-DisableLocalNetworkAccessChecks.ps1` | Detection | Detect compliance state for LNA DisableLocalNetworkAccessChecks. |
| `Disable-Blackboard-Local-Network-Access(Chrome-Edge).ps1` | Automation | Automation script for Disable Blackboard Local Network Access(Chrome Edge). |
| `Remediate-LNA-DisableLocalNetworkAccessChecks.ps1` | Remediation | Remediate LNA DisableLocalNetworkAccessChecks based on defined conditions. |


## 🔍 Technical Details
### `Detect-LNA-DisableLocalNetworkAccessChecks.ps1`
- **Functional Type:** Detection
- **Purpose:** Detect compliance state for LNA DisableLocalNetworkAccessChecks.
- **Technical Description:** This detection script evaluates LNA DisableLocalNetworkAccessChecks and returns compliance status. It is intended for Intune Proactive Remediations or scheduled automation. Exit codes: - Exit 1: Not Compliant (remediation should run) - Exit 0: Compliant
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Disable Local Network Access Checks (Chrome & Edge)\Detect-LNA-DisableLocalNetworkAccessChecks.ps1`
- **Observed Exit Codes:** `0`, `1`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.

#### Internal Functions
- `Initialize-Logging`
- `Test-LnaFlag`
- `Write-Log`

#### Key Cmdlets/Commands
- `Add-Content`
- `ConvertFrom-Json`
- `Get-Content`
- `Get-Date`
- `Initialize-Logging`
- `Join-Path`
- `New-Item`
- `Out-Null`
- `Test-LnaFlag`
- `Test-Path`
- `Write-Host`
- `Write-Log`

#### File/System Paths
- `C:\Intune`

### `Disable-Blackboard-Local-Network-Access(Chrome-Edge).ps1`
- **Functional Type:** Automation
- **Purpose:** Automation script for Disable Blackboard Local Network Access(Chrome Edge).
- **Technical Description:** This script automates tasks related to Disable Blackboard Local Network Access(Chrome Edge). Review prerequisites, permissions, and execution context before production deployment. Exit codes: - Exit 0: Completed successfully - Exit 1: Failed or requires further action
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Disable Local Network Access Checks (Chrome & Edge)\Disable-Blackboard-Local-Network-Access(Chrome-Edge).ps1`
- **Observed Exit Codes:** `0`, `1`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.

#### Parameters
| Name | Type | Mandatory | Default |
|---|---|---|---|
| `ForceVariant2` | `SwitchParameter` | No | - |

#### Internal Functions
- `Apply-And-Verify`
- `Ensure-PSCustomObject`
- `Fail`
- `Info`
- `Ok`
- `Set-LNAFlagDisabled`
- `Stop-Processes`
- `Wait-FileUnlocked`
- `Warn`

#### Key Cmdlets/Commands
- `Add-Member`
- `Apply-And-Verify`
- `cmd`
- `ConvertFrom-Json`
- `ConvertTo-Json`
- `Copy-Item`
- `Ensure-PSCustomObject`
- `Fail`
- `Get-Content`
- `Get-Date`
- `Get-Process`
- `Info`
- `Join-Path`
- `Ok`
- `Out-Null`
- *(+11 additional commands found in script)*

#### File/System Paths
- `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`
- `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- `C:\Program Files\Google\Chrome\Application\chrome.exe`
- `C:\Program Files\Microsoft\Edge\Application\msedge.exe`

### `Remediate-LNA-DisableLocalNetworkAccessChecks.ps1`
- **Functional Type:** Remediation
- **Purpose:** Remediate LNA DisableLocalNetworkAccessChecks based on defined conditions.
- **Technical Description:** This remediation script applies corrective actions for LNA DisableLocalNetworkAccessChecks. Use with Intune Proactive Remediations or on-demand execution. Exit codes: - Exit 0: Completed successfully - Exit 1: Failed or requires further action
- **Expected Run Context (Run As):** System or User (according to assignment settings and script requirements).
- **Path:** `Intune-Scripts\Intune - Remediation Scripts\Disable Local Network Access Checks (Chrome & Edge)\Remediate-LNA-DisableLocalNetworkAccessChecks.ps1`
- **Observed Exit Codes:** `0`, `1`
- **Technical Dependencies:**
  - Microsoft Intune environment with matching Proactive Remediation or script assignment settings.

#### Internal Functions
- `Ensure-PSCustomObject`
- `Get-BrowserExe`
- `Initialize-Logging`
- `Relaunch-Browser`
- `Set-LnaFlagV3Only`
- `Stop-BrowserProcesses`
- `Wait-FileUnlocked`
- `Write-Log`

#### Key Cmdlets/Commands
- `Add-Content`
- `Add-Member`
- `cmd`
- `ConvertFrom-Json`
- `ConvertTo-Json`
- `Copy-Item`
- `Ensure-PSCustomObject`
- `Get-BrowserExe`
- `Get-Content`
- `Get-Date`
- `Get-Process`
- `Initialize-Logging`
- `Join-Path`
- `New-Item`
- `Out-Null`
- *(+13 additional commands found in script)*

#### File/System Paths
- `C:\Intune`
- `C:\Program Files (x86)\Google\Chrome\Application\chrome.exe`
- `C:\Program Files (x86)\Microsoft\Edge\Application\msedge.exe`
- `C:\Program Files\Google\Chrome\Application\chrome.exe`
- `C:\Program Files\Microsoft\Edge\Application\msedge.exe`


## 🚀 Usage
```powershell
Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass
.\Detect-LNA-DisableLocalNetworkAccessChecks.ps1
.\Disable-Blackboard-Local-Network-Access(Chrome-Edge).ps1
.\Remediate-LNA-DisableLocalNetworkAccessChecks.ps1
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

