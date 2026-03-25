# 📦 Update-WingetPackages – Upgrade All Available Winget Packages

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Winget%20Package%20Updates-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Update-WingetPackages** checks whether the device has pending **Winget** upgrades and, if so, upgrades everything available in one pass.

The detection script locates `AppInstallerCLI.exe` inside the `WindowsApps` folder and runs `winget upgrade`. It treats short output as compliant and anything longer as evidence that updates are pending. The remediation script resolves the same Winget binary and runs:

```text
winget upgrade --all --force --silent
```

This package is intentionally broad. It does not filter by publisher, package ID, or source.

---

# ✨ Core Features

### 🔹 Dynamic Winget Resolution

The scripts do not assume a fixed `winget.exe` path:

* Search the `WindowsApps` package directory
* Resolve `Microsoft.DesktopAppInstaller*_x64*\AppInstallerCLI.exe`
* Use the discovered CLI path for both detection and remediation

---

### 🔹 Whole-Device Upgrade Mode

The remediation script upgrades all available packages:

* Uses `--all`
* Forces the upgrade attempt with `--force`
* Suppresses UI with `--silent`

---

### 🔹 Lightweight Detection Heuristic

Detection is based on the number of output lines returned by `winget upgrade`:

* Fewer than 3 lines -> treated as compliant
* 3 lines or more -> treated as non-compliant

This is practical, but it is still a heuristic rather than structured parsing.

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Update-WingetPackages
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Update-WingetPackages
│
├── README.md
├── Update-WingetPackages--Detect.ps1
└── Update-WingetPackages--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Update-WingetPackages--Detect.ps1
```

### Purpose

Checks whether Winget reports pending package upgrades.

### Logic

1. Locates `AppInstallerCLI.exe` under `WindowsApps`
2. Runs `winget upgrade`
3. Counts the returned lines
4. Returns `0` when the result set is smaller than 3 lines
5. Returns `1` when the output suggests available upgrades

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No Winget upgrades detected by the script heuristic |
| 1    | Pending Winget upgrades detected |

### Example

```powershell
.\Update-WingetPackages--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Update-WingetPackages--Remediate.ps1
```

### Purpose

Upgrades all packages that Winget considers eligible for update.

### Actions

1. Resolves the current `AppInstallerCLI.exe` path
2. Runs `winget upgrade --all --force --silent`

### Example

```powershell
.\Update-WingetPackages--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Dependencies

* Microsoft Desktop App Installer / Winget must already be installed

### Permissions

* The execution context must be able to run Winget successfully on the device

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Update-WingetPackages--Detect.ps1
```

### Remediation Script

```powershell
Update-WingetPackages--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Intune runs the **Detection Script**
2. Detection asks Winget for available upgrades
3. If the script sees enough output to indicate updates, detection exits with code **1**
4. Intune runs the **Remediation Script**
5. Remediation upgrades all available Winget packages silently

---

# 🛡 Operational Notes

* Detection uses output length rather than parsing package records, so changes in Winget output format can affect results.
* The current `.ps1` sources still carry duplicated inherited scaffolding above the active logic, but the functional part of the package is small and clear.
* `--all --force --silent` is aggressive. Test on pilot devices before assigning broadly.

---

## 📜 License

This project is licensed under the [MIT License](https://opensource.org/licenses/MIT).

---

## 👤 Author

**Mohammad Abdulkader Omar**  
Website: https://momar.tech  
Version: **1.2**

---

## ☕ Support

If this project helps you, consider supporting it:

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-☕-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.
