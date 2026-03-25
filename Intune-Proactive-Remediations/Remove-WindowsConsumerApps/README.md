# 🧹 Remove-WindowsConsumerApps – Built-In AppX Package Removal

![License](https://img.shields.io/badge/license-MIT-blue.svg)
![PowerShell](https://img.shields.io/badge/powershell-5.1%2B-blue.svg)
![Platform](https://img.shields.io/badge/Windows-10%2F11-blue.svg)
![Automation](https://img.shields.io/badge/Intune-Proactive%20Remediation-brightgreen.svg)
![Mode](https://img.shields.io/badge/Automation-AppX%20Cleanup-lightgrey.svg)
![Version](https://img.shields.io/badge/version-1.2-green.svg)
---

# 📖 Overview

**Remove-WindowsConsumerApps** is an Intune remediation package that looks for a small set of built-in consumer AppX packages and removes them when they are still installed.

The detection script queries `Get-AppxPackage -AllUsers` and compares the installed package names to a fixed list:

* `Microsoft.XboxApp`
* `Microsoft.XboxGameOverlay`
* `Microsoft.Xbox.TCUI`
* `Microsoft.MicrosoftSolitaireCollection`
* `Microsoft.549981C3F5F10` (Cortana)

If one or more of those packages are present, remediation runs. The remediation script attempts to remove matching installed AppX packages for all users and also attempts to remove provisioned packages from the online image.

This package is useful when you want to strip a known subset of consumer-facing Microsoft apps from managed Windows devices.

---

# ✨ Core Features

### 🔹 Local Logging

* Writes Intune-style logs under <SystemDrive>\IntuneLogs\Remove-WindowsConsumerApps
* Records detection and remediation activity locally, including intentional always-run behavior where applicable
---

# 📂 Project Structure

```text
Remove-WindowsConsumerApps
│
├── README.md
├── Remove-WindowsConsumerApps--Detect.ps1
└── Remove-WindowsConsumerApps--Remediate.ps1
```

---

# 🚀 Scripts Included

## 🔎 Detection Script

**File**

```powershell
Remove-WindowsConsumerApps--Detect.ps1
```

### Purpose

Checks whether any of the targeted consumer AppX packages are still installed.

### Logic

1. Defines the package names that should be removed
2. Queries `Get-AppxPackage -AllUsers`
3. Filters the installed packages against the configured target list
4. Returns exit code `1` when one or more matches are found

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | None of the targeted consumer apps are installed |
| 1    | One or more targeted consumer apps are installed |

### Key References

* Command: `Get-AppxPackage -AllUsers`
* Packages: `Microsoft.XboxApp`, `Microsoft.XboxGameOverlay`, `Microsoft.Xbox.TCUI`, `Microsoft.MicrosoftSolitaireCollection`, `Microsoft.549981C3F5F10`

### Example

```powershell
.\Remove-WindowsConsumerApps--Detect.ps1
```

---

## 🛠 Remediation Script

**File**

```powershell
Remove-WindowsConsumerApps--Remediate.ps1
```

### Purpose

Attempts to remove the targeted consumer AppX packages from the device.

### Actions

1. Defines the same target package list used by detection
2. Finds installed matching packages with `Get-AppxPackage -AllUsers`
3. Removes installed packages by using `Remove-AppxPackage -AllUsers`
4. Attempts to remove corresponding provisioned packages from the online image
5. Returns success when no targeted packages remain to process or after removal succeeds

### Exit Codes

| Code | Status |
| ---- | ------ |
| 0    | No targeted apps were found, or removal completed |
| 1    | The script returned an error while attempting package removal |

### Key References

* Command: `Get-AppxPackage -AllUsers`
* Command: `Remove-AppxPackage -AllUsers`
* Command: `Remove-AppxProvisionedPackage -Online`

### Example

```powershell
.\Remove-WindowsConsumerApps--Remediate.ps1
```

---

# ⚙️ Requirements

### Operating System

* Windows 10
* Windows 11

### PowerShell

* PowerShell **5.1 or later**

### Permissions

* Permission to enumerate AppX packages for all users
* Permission to remove installed and provisioned AppX packages

### Logging

* Logs are written under `<SystemDrive>\IntuneLogs\Remove-WindowsConsumerApps`

---

# 🧭 Intune Deployment

This solution is intended for **Microsoft Intune Proactive Remediations**.

### Detection Script

```powershell
Remove-WindowsConsumerApps--Detect.ps1
```

### Remediation Script

```powershell
Remove-WindowsConsumerApps--Remediate.ps1
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
2. Detection checks whether the targeted AppX packages are installed
3. If one or more matches are found, detection exits with code `1`
4. Intune runs the **Remediation Script**
5. Remediation attempts to remove the matching installed and provisioned packages

---

# 🛡 Operational Notes

* The package only targets the hard-coded app list in the script
* The remediation logic attempts provisioned package cleanup, but the current script body depends on a variable that is not initialized inside the file before that step
* As written, this package is best treated as a focused consumer-app cleanup rather than a generic AppX debloat script
* Test carefully on pilot devices before broad rollout, especially if Store apps are managed elsewhere

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
