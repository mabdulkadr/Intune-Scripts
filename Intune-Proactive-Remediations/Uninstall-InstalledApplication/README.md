# 🗑️ Uninstall-InstalledApplication – Registry-Based Software Removal Template

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-Application%20Removal-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Uninstall-InstalledApplication** is a generic Intune remediation template for detecting blacklisted installed applications in the Windows uninstall registry and launching their uninstall commands.

The detection script searches both 64-bit and 32-bit uninstall registry locations under `HKLM` and compares discovered display names to a configurable blacklist array. The remediation script uses the same search logic, reads the uninstall string for matching entries, and attempts to run either a silent MSI uninstall or the vendor-provided uninstall command with `/S`.

The current files are still template-style and require customization. The blacklist currently contains placeholder entries such as `APP 1` and `APP 2`, and parts of the remediation logic still need cleanup before this should be considered production-ready.

---

# ✨ Core Features

### 🔹 Registry-Based Detection

* Reads uninstall entries from the standard 64-bit uninstall key
* Reads uninstall entries from the WOW6432Node uninstall key
* Compares display names to a configured blacklist

### 🔹 Blacklist-Driven Removal

* Uses a simple app name array as the removal scope
* Triggers remediation only when a listed application is present
* Is designed for repeated reuse across different software removal scenarios

### 🔹 Silent Uninstall Attempt

* Parses `UninstallString`
* Tries MSI removal through `msiexec.exe /X ... /qn`
* Falls back to appending `/S` for non-MSI uninstall commands

### 🔹 Template-Oriented Design

* Requires the blacklist to be customized
* Still contains placeholder values and script issues that should be reviewed
* Is best treated as a starting point for software-specific remediation

---

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Uninstall-InstalledApplication
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Uninstall-InstalledApplication
│
├── README.md
├── Uninstall-InstalledApplication--Detect.ps1
└── Uninstall-InstalledApplication--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Uninstall-InstalledApplication--Detect.ps1
```

### Purpose

Checks whether any blacklisted application names are present in the Windows uninstall registry.

### Logic

1. Reads uninstall entries from `HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
2. Reads uninstall entries from `HKLM:\Software\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall`
3. Compares `DisplayName` or `DisplayName_Localized` to the configured blacklist
4. Returns exit code `1` when one or more matching applications are found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No blacklisted applications were detected |
| 1    | One or more blacklisted applications were detected |

### Key References

* Registry: `HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
* Registry: `HKLM:\Software\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall`
* Placeholders: `APP 1`, `APP 2`

### Example

```powershell
.\Uninstall-InstalledApplication--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Uninstall-InstalledApplication--Remediate.ps1
```

### Purpose

Attempts to uninstall blacklisted applications by using the uninstall command stored in the registry.

### Actions

1. Reads the same 64-bit and 32-bit uninstall registry locations as detection
2. Matches entries against the configured blacklist
3. Reads the uninstall string for matching entries
4. Tries a silent MSI uninstall when the uninstall string references `msiexec`
5. Otherwise attempts to launch the vendor uninstall command with `/S`

### Key References

* Registry: `HKLM:\Software\Microsoft\Windows\CurrentVersion\Uninstall`
* Registry: `HKLM:\Software\WOW6432NODE\Microsoft\Windows\CurrentVersion\Uninstall`
* Command: `msiexec.exe`

### Example

```powershell
.\Uninstall-InstalledApplication--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to read uninstall registry keys
* Permission to launch uninstall commands for the targeted applications

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Uninstall-InstalledApplication`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Uninstall-InstalledApplication--Detect.ps1
```

### Remediation Script

```powershell
Uninstall-InstalledApplication--Remediate.ps1
```

### Recommended Settings

| Setting                                     | Value |
| ------------------------------------------- | ----- |
| Run script in 64-bit PowerShell             | Yes   |
| Run this script using logged-on credentials | No    |
| Enforce script signature check              | No    |

---

# 🔧 Typical Workflow

1. Populate the blacklist array with the applications you want to remove
2. Intune runs the **Detection Script**
3. Detection checks both uninstall registry branches
4. If a blacklisted application is found, detection exits with code `1`
5. Intune runs the **Remediation Script**
6. Remediation attempts to execute the uninstall command silently

---

# 🛡 Operational Notes

* The current package is still a template and requires app-specific customization
* The remediation script contains implementation issues in its current form, including inconsistent variable usage between 32-bit and 64-bit loops
* Silent uninstall behavior depends entirely on the uninstall string and whether the target installer supports the arguments the script appends
* Test carefully on pilot devices before production use

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

[![Buy Me A Coffee](https://img.shields.io/badge/Buy%20Me%20A%20Coffee-%E2%98%95-FFDD00?style=for-the-badge)](https://www.buymeacoffee.com/mabdulkadrx)

---

## ⚠ Disclaimer

These scripts are provided as-is. Test them in a staging environment before applying them to production. The author is not responsible for any unintended outcomes resulting from their use.
