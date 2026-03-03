
# 📦 Winget Auto Update (Detection + Remediation)

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Mode](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Context](https://img.shields.io/badge/Run%20As-System-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.0-green.svg)

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## 📖 Overview

**Winget Auto Update** is a lightweight PowerShell-based solution designed for **automated third-party application patching** using **Windows Package Manager (winget)**.

It is intended for deployment via:

- Microsoft Intune **Proactive Remediations**
- Device-level remediation scripts
- Automated compliance enforcement workflows

The solution consists of:

- 🔍 **Detection Script** → Identifies devices with pending app updates  
- 🛠 **Remediation Script** → Silently upgrades all supported applications  

---

## 🧠 Architecture

### 🔹 Detection Phase – `detection_winget-update-detect.ps1`

This script:

- Dynamically resolves `AppInstallerCLI.exe` from:
```

C:\Program Files\WindowsApps\Microsoft.DesktopAppInstaller_**x64*_*\AppInstallerCLI.exe

```
- Executes:
```

winget upgrade

```
- Evaluates output line count
- Returns:

| Condition | Exit Code | Result |
|-----------|-----------|--------|
| No updates available | `0` | Compliant |
| Updates available | `1` | Not Compliant |
| Execution error | `1` | Not Compliant |

This allows Intune to trigger remediation only when required.

---

### 🔹 Remediation Phase – `remediation_winget-upgrade-remediate.ps1`

This script:

- Resolves the Winget executable dynamically
- Executes:

```

winget upgrade --all --force --silent

```

#### Parameter Explanation

| Parameter | Purpose |
|------------|----------|
| `--all` | Upgrade all applications with available updates |
| `--force` | Override version checks or reinstall if required |
| `--silent` | Suppress UI prompts (fully unattended execution) |

The remediation runs entirely in **SYSTEM context** and requires no user interaction.

---

## 🗂 Repository Structure

```

Winget-Auto-Update
├── detection_winget-update-detect.ps1
├── remediation_winget-upgrade-remediate.ps1
├── README.md

```

---

## ⚙️ Requirements

### System
- Windows 10 / Windows 11
- Windows PowerShell 5.1
- Microsoft.DesktopAppInstaller (Winget) installed

### Execution Context
- Must run in **64-bit PowerShell**
- Recommended deployment as:
  - Intune Proactive Remediation
  - Device-based assignment
- Requires internet connectivity

---

## 🚀 Deployment in Intune (Recommended)

1. Navigate to:
```

Devices → Scripts and Remediations → Proactive Remediations

```
2. Upload:
- Detection script → `detection_winget-update-detect.ps1`
- Remediation script → `remediation_winget-upgrade-remediate.ps1`
3. Configure:
- Run script in 64-bit PowerShell → ✅ Yes
- Run as SYSTEM → ✅ Yes
4. Assign to device group

---

## 🔎 Typical Workflow

1. Intune runs Detection script.
2. If updates are found → Exit 1.
3. Intune triggers Remediation.
4. All applications are upgraded silently.
5. Next cycle → Device returns Compliant.

---

## 🛡 Operational Notes

- Winget source configuration must be healthy.
- Store apps may require additional servicing.
- Some applications may not support silent upgrades.
- Always test in a pilot group before production rollout.
- Monitor update logs in:
```

C:\ProgramData\Microsoft\IntuneManagementExtension\Logs

```

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: **momar.tech**  
Version: **1.0**

---

☕ Support

If this repo helps you, you can support it here:
https://www.buymeacoffee.com/mabdulkadrx


---

## ⚠ Disclaimer

This script is provided **as-is**.

- Validate behavior in staging environment
- Ensure change management approval
- Confirm compatibility with organizational policies
- Monitor application impact post-deployment
